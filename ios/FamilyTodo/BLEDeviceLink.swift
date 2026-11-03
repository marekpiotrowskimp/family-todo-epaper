@preconcurrency import CoreBluetooth  // typy CB nie są Sendable; delegaci działają na kolejce głównej
import Foundation
import TodoCore

/// `DeviceLink` po BLE: szuka urządzenia z usługą synchronizacji, wymienia ramki `FrameCodec`
/// z wiadomościami `DeviceProtocol` i rozłącza się po sesji. Bez parowania ani szyfrowania łącza.
/// Poza sesją może obserwować zasięg (`startDiscovery`) i zgłaszać, że urządzenie jest w pobliżu.
/// Delegaci CoreBluetooth działają na kolejce głównej, więc cały stan jest izolowany na MainActor.
@MainActor
final class BLEDeviceLink: NSObject, DeviceLink {
    // Te same UUID co w include/config.h firmware.
    static let serviceUUID = CBUUID(string: "8b1f0001-6a4e-4d2b-9c7e-3f5a2b1c0d10")
    static let requestUUID = CBUUID(string: "8b1f0002-6a4e-4d2b-9c7e-3f5a2b1c0d10")
    static let responseUUID = CBUUID(string: "8b1f0003-6a4e-4d2b-9c7e-3f5a2b1c0d10")

    /// Urządzenie może być zajęte pełnym odświeżeniem e-papera (~3 s), stąd zapas.
    private let timeout: Duration = .seconds(15)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var requestCharacteristic: CBCharacteristic?
    private var responseCharacteristic: CBCharacteristic?
    private var reassembler = FrameReassembler()

    private var stepWaiter: CheckedContinuation<Void, Error>?
    private var responseWaiter: CheckedContinuation<Data, Error>?
    /// Odpowiedź, która przyszła, zanim skończyliśmy wysyłać żądanie (np. `bad_frame` w połowie).
    private var earlyResponse: Result<Data, Error>?
    private var timeoutTask: Task<Void, Never>?
    /// `true` od `connect()` do końca sesji; wtedy wykrycie urządzenia oznacza połączenie.
    private var connecting = false
    private var onDeviceSeen: (@MainActor () -> Void)?

    // MARK: - Wykrywanie

    /// Skanuje w poszukiwaniu wyświetlacza i woła `handler` po każdym wykryciu w nowym skanie.
    /// Kolejne zgłoszenie wymaga `rescan()` (skan bez duplikatów zgłasza urządzenie raz).
    func startDiscovery(_ handler: @escaping @MainActor () -> Void) {
        onDeviceSeen = handler
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
        rescan()
    }

    func stopDiscovery() {
        onDeviceSeen = nil
        if !connecting { central?.stopScan() }
    }

    /// Nowy skan, żeby urządzenie widoczne nadal zostało zgłoszone ponownie.
    func rescan() {
        guard let central, central.state == .poweredOn, !connecting, onDeviceSeen != nil else { return }
        central.stopScan()
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }

    // MARK: - DeviceLink

    func connect() async throws {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
        guard let central else { throw SyncError.transport("bluetooth") }
        if central.state != .poweredOn {
            try await waitStep()  // centralManagerDidUpdateState
        }
        guard central.state == .poweredOn else { throw SyncError.transport("bluetooth_off") }
        connecting = true
        central.stopScan()
        central.scanForPeripherals(withServices: [Self.serviceUUID])
        try await waitStep()  // znaleziono, połączono, odkryto charakterystyki, włączono notyfikacje
    }

    func hello() async throws -> DeviceHello {
        try DeviceProtocol.decodeHello(await request(.hello))
    }

    func authenticate(userId: String, displayName: String, mac: Data) async throws {
        try DeviceProtocol.decodeAck(await request(.auth(userId: userId, displayName: displayName, mac: mac)))
    }

    func push(_ tasks: [TodoTask]) async throws -> [PushOutcome] {
        try DeviceProtocol.decodePush(await request(.push(tasks)))
    }

    func pull(since: UInt32, limit: Int) async throws -> DevicePull {
        try DeviceProtocol.decodePull(await request(.pull(since: since, limit: limit)))
    }

    func disconnect() async {
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        reset(failing: SyncError.transport("disconnected"))
    }

    // MARK: - Wymiana wiadomości

    private func request(_ request: DeviceRequest) async throws -> Data {
        guard let peripheral, let characteristic = requestCharacteristic else {
            throw SyncError.transport("not_connected")
        }
        reassembler.reset()
        earlyResponse = nil
        // Jedna ramka = jeden zapis ATT; długość ograniczona przez wynegocjowane MTU.
        let frameSize = peripheral.maximumWriteValueLength(for: .withoutResponse)
        let frames = FrameCodec.split(DeviceProtocol.encode(request), maxFrameBytes: frameSize)
        for frame in frames {
            peripheral.writeValue(frame, for: characteristic, type: .withResponse)
            try await waitStep()  // didWriteValueFor
            if earlyResponse != nil { break }  // urządzenie już odpowiedziało; dalsze ramki są zbędne
        }
        if let early = earlyResponse {
            earlyResponse = nil
            return try early.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            responseWaiter = continuation
            armTimeout()
        }
    }

    private func waitStep() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stepWaiter = continuation
            armTimeout()
        }
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        let timeout = self.timeout
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return  // anulowane: krok zakończył się na czas
            }
            self?.reset(failing: SyncError.transport("timeout"))
        }
    }

    private func finishStep(_ error: Error? = nil) {
        timeoutTask?.cancel()
        let waiter = stepWaiter
        stepWaiter = nil
        if let error { waiter?.resume(throwing: error) } else { waiter?.resume() }
    }

    private func finishResponse(_ result: Result<Data, Error>) {
        guard let waiter = responseWaiter else {
            // Jeszcze wysyłamy żądanie: odbierze je `request` po bieżącym zapisie,
            // a timeout trwającego kroku zapisu zostaje nietknięty.
            earlyResponse = result
            return
        }
        timeoutTask?.cancel()
        responseWaiter = nil
        waiter.resume(with: result)
    }

    private func reset(failing error: Error) {
        central?.stopScan()
        connecting = false
        peripheral = nil
        requestCharacteristic = nil
        responseCharacteristic = nil
        reassembler.reset()
        earlyResponse = nil
        finishStep(error)
        if let waiter = responseWaiter {
            responseWaiter = nil
            waiter.resume(throwing: error)
        }
    }
}

extension BLEDeviceLink: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if central.state == .poweredOn {
                finishStep()
                rescan()
            } else if central.state != .unknown && central.state != .resetting {
                reset(failing: SyncError.transport("bluetooth_off"))
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        MainActor.assumeIsolated {
            guard connecting else {
                central.stopScan()
                onDeviceSeen?()
                return
            }
            guard self.peripheral == nil else { return }
            central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
    ) {
        MainActor.assumeIsolated {
            reset(failing: SyncError.transport(error?.localizedDescription ?? "connect_failed"))
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        MainActor.assumeIsolated {
            reset(failing: SyncError.transport("disconnected"))
        }
    }
}

extension BLEDeviceLink: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
                return reset(failing: SyncError.transport("service_missing"))
            }
            peripheral.discoverCharacteristics([Self.requestUUID, Self.responseUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        MainActor.assumeIsolated {
            let characteristics = service.characteristics ?? []
            guard error == nil,
                  let request = characteristics.first(where: { $0.uuid == Self.requestUUID }),
                  let response = characteristics.first(where: { $0.uuid == Self.responseUUID })
            else { return reset(failing: SyncError.transport("characteristics_missing")) }
            requestCharacteristic = request
            responseCharacteristic = response
            // Bez szyfrowania łącza: subskrypcja indications nie wywołuje parowania iOS.
            peripheral.setNotifyValue(true, for: response)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?
    ) {
        MainActor.assumeIsolated {
            if let error { return reset(failing: SyncError.transport(error.localizedDescription)) }
            finishStep()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        MainActor.assumeIsolated {
            if let error { return reset(failing: SyncError.transport(error.localizedDescription)) }
            finishStep()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        MainActor.assumeIsolated {
            guard characteristic.uuid == Self.responseUUID, let value = characteristic.value else { return }
            switch reassembler.feed(value) {
            case .incomplete:
                break
            case let .complete(message):
                finishResponse(.success(message))
            case .error:
                finishResponse(.failure(SyncError.transport("bad_frame")))
            }
        }
    }
}
