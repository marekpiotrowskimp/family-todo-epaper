import CryptoKit
import Foundation

public struct DeviceHello: Equatable, Sendable {
    public var nonce: Data
    public var storeId: String
    public var revision: UInt32

    public init(nonce: Data, storeId: String, revision: UInt32) {
        self.nonce = nonce
        self.storeId = storeId
        self.revision = revision
    }
}

public struct DevicePull: Equatable, Sendable {
    public var storeId: String
    /// Kursor do następnego `pull`; przy `more == false` równy rewizji urządzenia.
    public var revision: UInt32
    public var tasks: [TodoTask]
    public var more: Bool

    public init(storeId: String, revision: UInt32, tasks: [TodoTask], more: Bool) {
        self.storeId = storeId
        self.revision = revision
        self.tasks = tasks
        self.more = more
    }
}

public enum PushOutcome: String, Sendable, Equatable {
    case inserted
    case updated
    case ignored
    case rejectedFull = "rejected_full"
    case rejectedInvalid = "rejected_invalid"
}

public enum SyncError: Error, Equatable {
    /// bad_mac, unknown_member, not_authenticated, no_session
    case unauthorized
    /// Inny błąd zgłoszony przez urządzenie, np. "batch_too_large", "bad_request", "bad_frame".
    case device(String)
    case malformedResponse
    case transport(String)
}

public enum SyncLimits {
    /// To samo co `kMaxBatch` w firmware.
    public static let batchSize = 20
}

public enum DeviceRequest: Equatable, Sendable {
    case hello
    case auth(userId: String, displayName: String, mac: Data)
    case push([TodoTask])
    case pull(since: UInt32, limit: Int)
}

/// Kodowanie wiadomości JSON protokołu (patrz spec „rodzinne-todo-ble”, sekcja „Protokół”).
/// Dane binarne (nonce, mac) są przesyłane jako hex małymi literami.
public enum DeviceProtocol {
    private static let unauthorizedCodes: Set<String> = ["bad_mac", "unknown_member", "not_authenticated", "no_session"]

    public static func encode(_ request: DeviceRequest) -> Data {
        let object: [String: Any]
        switch request {
        case .hello:
            object = ["op": "hello"]
        case let .auth(userId, displayName, mac):
            object = ["op": "auth", "user": userId, "name": displayName, "mac": Hex.encode(mac)]
        case let .push(tasks):
            object = ["op": "push", "tasks": tasks.map(TaskWire.jsonObject)]
        case let .pull(since, limit):
            object = ["op": "pull", "since": since, "limit": limit]
        }
        return WireJSON.data(object)
    }

    public static func decodeHello(_ data: Data) throws -> DeviceHello {
        let object = try successObject(data)
        guard let nonceHex = object["nonce"] as? String, let nonce = Hex.decode(nonceHex), !nonce.isEmpty,
              let store = object["store"] as? String,
              let revision = revision(object["rev"])
        else { throw SyncError.malformedResponse }
        return DeviceHello(nonce: nonce, storeId: store, revision: revision)
    }

    /// Zwraca normalnie przy `{"ok":true}`; błędy rzuca jako `SyncError`.
    public static func decodeAck(_ data: Data) throws {
        _ = try successObject(data)
    }

    public static func decodePush(_ data: Data) throws -> [PushOutcome] {
        let object = try successObject(data)
        guard let results = object["results"] as? [String] else { throw SyncError.malformedResponse }
        return try results.map { name in
            guard let outcome = PushOutcome(rawValue: name) else { throw SyncError.malformedResponse }
            return outcome
        }
    }

    public static func decodePull(_ data: Data) throws -> DevicePull {
        let object = try successObject(data)
        guard let store = object["store"] as? String,
              let revision = revision(object["rev"]),
              let more = object["more"] as? Bool,
              let rawTasks = object["tasks"] as? [[String: Any]]
        else { throw SyncError.malformedResponse }
        do {
            return DevicePull(storeId: store, revision: revision, tasks: try rawTasks.map(TaskWire.task(from:)), more: more)
        } catch {
            throw SyncError.malformedResponse
        }
    }

    /// Obiekt odpowiedzi z `"ok":true` albo odpowiedni `SyncError`.
    private static func successObject(_ data: Data) throws -> [String: Any] {
        guard let object = WireJSON.object(data), let ok = object["ok"] as? Bool else {
            throw SyncError.malformedResponse
        }
        if ok { return object }
        guard let code = object["err"] as? String else { throw SyncError.malformedResponse }
        throw unauthorizedCodes.contains(code) ? SyncError.unauthorized : SyncError.device(code)
    }

    private static func revision(_ value: Any?) -> UInt32? {
        guard let number = value as? Int64, let revision = UInt32(exactly: number) else { return nil }
        return revision
    }
}

public enum DeviceAuth {
    /// HMAC-SHA256(klucz rodziny, nonce || UTF-8(userId)), identycznie jak `todo::authMac`.
    public static func mac(secret: Data, nonce: Data, userId: String) -> Data {
        let code = HMAC<SHA256>.authenticationCode(for: nonce + Data(userId.utf8), using: SymmetricKey(data: secret))
        return Data(code)
    }
}

/// Hex małymi literami (format pól binarnych w protokole).
enum Hex {
    static func encode(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func decode(_ string: String) -> Data? {
        let chars = Array(string.utf8)
        guard chars.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(chars.count / 2)
        for i in stride(from: 0, to: chars.count, by: 2) {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            bytes.append(hi << 4 | lo)
        }
        return Data(bytes)
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
        default: return nil
        }
    }
}
