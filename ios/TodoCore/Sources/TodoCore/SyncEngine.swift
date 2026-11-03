import Foundation

/// Połączenie z urządzeniem na poziomie operacji protokołu. Implementacja produkcyjna:
/// CoreBluetooth + `FrameCodec` + `DeviceProtocol` (w aplikacji).
@MainActor
public protocol DeviceLink: AnyObject {
    func connect() async throws
    func hello() async throws -> DeviceHello
    /// `displayName` trafia do rejestru urządzenia i pojawia się na ekranie przy zadaniach tej osoby.
    func authenticate(userId: String, displayName: String, mac: Data) async throws
    func push(_ tasks: [TodoTask]) async throws -> [PushOutcome]
    func pull(since: UInt32, limit: Int) async throws -> DevicePull
    func disconnect() async
}

public struct Credentials: Sendable, Equatable {
    public var userId: String
    public var displayName: String
    /// Wspólny klucz rodziny (ten sam w aplikacji i firmware), nie sekret konkretnego telefonu.
    public var secret: Data

    public init(userId: String, displayName: String, secret: Data) {
        self.userId = userId
        self.displayName = displayName
        self.secret = secret
    }
}

public struct SyncReport: Equatable, Sendable {
    public var pushedIDs: Set<String>
    public var pulledChangedIDs: Set<String>
    /// Zadania odrzucone przez urządzenie (np. pełna pamięć); pozostają oczekujące.
    public var rejectedIDs: Set<String>

    public init(pushedIDs: Set<String> = [], pulledChangedIDs: Set<String> = [], rejectedIDs: Set<String> = []) {
        self.pushedIDs = pushedIDs
        self.pulledChangedIDs = pulledChangedIDs
        self.rejectedIDs = rejectedIDs
    }
}

/// Jedna krótka sesja: connect → hello → auth → push (paczki po 20) → pull (strony po 20) → disconnect.
@MainActor
public final class SyncEngine {
    private let repository: TaskRepository
    private let link: DeviceLink
    private let credentials: Credentials

    public init(repository: TaskRepository, link: DeviceLink, credentials: Credentials) {
        self.repository = repository
        self.link = link
        self.credentials = credentials
    }

    public func sync() async throws -> SyncReport {
        do {
            try await link.connect()
            let report = try await runSession()
            await link.disconnect()
            return report
        } catch {
            await link.disconnect()
            throw error
        }
    }

    private func runSession() async throws -> SyncReport {
        let hello = try await link.hello()
        let mac = DeviceAuth.mac(secret: credentials.secret, nonce: hello.nonce, userId: credentials.userId)
        try await link.authenticate(userId: credentials.userId, displayName: credentials.displayName, mac: mac)

        // Brak kursora albo nowy storeId: urządzenie nie zna naszych rekordów, odtwarzamy je w całości.
        let fullSync = repository.syncCursor?.storeId != hello.storeId
        var report = SyncReport()
        try await pushChanges(all: fullSync, into: &report)

        var since = fullSync ? 0 : repository.syncCursor?.revision ?? 0
        while true {
            let page = try await link.pull(since: since, limit: SyncLimits.batchSize)
            // Inny storeId w trakcie sesji = odpowiedź nie z tego urządzenia albo jego reset; nie mieszamy danych.
            guard page.storeId == hello.storeId else { throw SyncError.malformedResponse }
            report.pulledChangedIDs.formUnion(repository.applyRemote(page.tasks))
            repository.setSyncCursor(SyncCursor(storeId: page.storeId, revision: page.revision))
            guard page.more else { break }
            // Kursor musi rosnąć, inaczej urządzenie zapętliłoby synchronizację.
            guard page.revision > since else { throw SyncError.malformedResponse }
            since = page.revision
        }
        return report
    }

    private func pushChanges(all: Bool, into report: inout SyncReport) async throws {
        let pending = repository.pendingIDs
        let tasks = repository.allTasks
            .filter { all || pending.contains($0.id) }
            .sorted { $0.id.utf8.lexicographicallyPrecedes($1.id.utf8) }
        var start = 0
        while start < tasks.count {
            let batch = Array(tasks[start..<min(start + SyncLimits.batchSize, tasks.count)])
            let outcomes = try await link.push(batch)
            guard outcomes.count == batch.count else { throw SyncError.malformedResponse }
            var settled: [String: Date] = [:]
            for (task, outcome) in zip(batch, outcomes) {
                switch outcome {
                case .inserted, .updated, .ignored:
                    settled[task.id] = task.updatedAt
                    report.pushedIDs.insert(task.id)
                case .rejectedInvalid:
                    // Urządzenie nigdy go nie przyjmie; ponawianie nic nie da.
                    settled[task.id] = task.updatedAt
                    report.rejectedIDs.insert(task.id)
                case .rejectedFull:
                    report.rejectedIDs.insert(task.id)
                }
            }
            repository.markSynced(settled)
            start += batch.count
        }
    }
}
