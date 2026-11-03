import Foundation
@testable import TodoCore

/// Skryptowany odpowiednik urządzenia: zapisuje wywołania i zwraca ustawione odpowiedzi.
/// Nie używa produkcyjnego LWW ani HMAC — MAC porównuje ze wspólnym wektorem testowym.
@MainActor
final class FakeDeviceLink: DeviceLink {
    enum Step: Equatable { case connect, hello, auth, push, pull }

    var helloResponse = DeviceHello(nonce: Vectors.nonce, storeId: "S1", revision: 0)
    var acceptedMac = Vectors.annaMac
    var outcome: (TodoTask) -> PushOutcome = { _ in .inserted }
    /// since -> odpowiedź; brak wpisu = pusta strona z revision == since.
    var pages: [UInt32: DevicePull] = [:]
    var failOn: Step?
    var failOnPullSince: UInt32?
    var onPush: (([TodoTask]) -> Void)?

    private(set) var calls: [String] = []
    private(set) var receivedMacs: [Data] = []
    private(set) var receivedNames: [String] = []
    private(set) var pushedBatches: [[TodoTask]] = []
    private(set) var pullRequests: [(since: UInt32, limit: Int)] = []
    private(set) var disconnectCount = 0

    var pushedTasks: [TodoTask] { pushedBatches.flatMap { $0 } }

    func connect() async throws {
        calls.append("connect")
        if failOn == .connect { throw SyncError.transport("connect") }
    }

    func hello() async throws -> DeviceHello {
        calls.append("hello")
        if failOn == .hello { throw SyncError.transport("hello") }
        return helloResponse
    }

    func authenticate(userId: String, displayName: String, mac: Data) async throws {
        calls.append("auth")
        receivedMacs.append(mac)
        receivedNames.append(displayName)
        if failOn == .auth { throw SyncError.transport("auth") }
        if mac != acceptedMac { throw SyncError.unauthorized }
    }

    func push(_ tasks: [TodoTask]) async throws -> [PushOutcome] {
        calls.append("push")
        if failOn == .push { throw SyncError.transport("push") }
        pushedBatches.append(tasks)
        onPush?(tasks)
        return tasks.map(outcome)
    }

    func pull(since: UInt32, limit: Int) async throws -> DevicePull {
        calls.append("pull")
        pullRequests.append((since, limit))
        if failOn == .pull || failOnPullSince == since { throw SyncError.transport("pull") }
        return pages[since] ?? DevicePull(storeId: helloResponse.storeId, revision: since, tasks: [], more: false)
    }

    func disconnect() async {
        calls.append("disconnect")
        disconnectCount += 1
    }
}

@MainActor
final class FakeNotificationCenter: NotificationScheduling {
    private(set) var pending: [String: ReminderRequest] = [:]
    private(set) var scheduled: [ReminderRequest] = []
    private(set) var cancelled: [String] = []

    init(pending: [ReminderRequest] = []) {
        for r in pending { self.pending[r.id] = r }
    }

    func pendingReminders() async -> [ReminderRequest] {
        pending.values.sorted { $0.id < $1.id }
    }

    func schedule(_ reminder: ReminderRequest) async throws {
        scheduled.append(reminder)
        pending[reminder.id] = reminder  // ten sam identyfikator podmienia powiadomienie, jak w iOS
    }

    func cancel(ids: [String]) async {
        cancelled += ids
        for id in ids { pending[id] = nil }
    }
}
