import Foundation

public struct ReminderRequest: Equatable, Sendable {
    /// Równe `TodoTask.id`, dzięki czemu przypomnienie da się podmienić lub anulować.
    public var id: String
    public var fireAt: Date
    public var title: String

    public init(id: String, fireAt: Date, title: String) {
        self.id = id
        self.fireAt = fireAt
        self.title = title
    }
}

/// Abstrakcja nad `UNUserNotificationCenter`.
@MainActor
public protocol NotificationScheduling: AnyObject {
    func pendingReminders() async -> [ReminderRequest]
    func schedule(_ reminder: ReminderRequest) async throws
    func cancel(ids: [String]) async
}

public enum ReminderPlanner {
    /// Limit iOS dla oczekujących powiadomień lokalnych jednej aplikacji.
    public static let maxPending = 64

    /// Przypomnienia dla aktywnych, nieusuniętych zadań użytkownika `userId` z `reminderAt > now`,
    /// rosnąco po `fireAt`, najwyżej `maxPending`.
    public static func plan(tasks: [TodoTask], userId: String, now: Date) -> [ReminderRequest] {
        let requests = tasks.compactMap { task -> ReminderRequest? in
            guard task.ownerId == userId, task.status == .active, !task.deleted,
                  let fireAt = task.reminderAt, fireAt > now
            else { return nil }
            // Pełne ms: tyle precyzji przechowuje powiadomienie, więc porównanie w reconcile jest dokładne.
            return ReminderRequest(id: task.id, fireAt: WireTime.wholeMilliseconds(fireAt), title: task.title)
        }
        let sorted = requests.sorted { $0.fireAt != $1.fireAt ? $0.fireAt < $1.fireAt : $0.id < $1.id }
        return Array(sorted.prefix(maxPending))
    }
}

/// Uzgadnia zaplanowane powiadomienia z bieżącą listą zadań: anuluje zbędne,
/// planuje brakujące i zmienione, niezmienionych nie dotyka.
@MainActor
public final class ReminderScheduler {
    private let center: NotificationScheduling
    private let userId: String
    private let now: () -> Date
    /// Błąd ostatniego planowania powiadomienia (np. brak zgody użytkownika).
    public private(set) var lastError: Error?

    public init(center: NotificationScheduling, userId: String, now: @escaping () -> Date = Date.init) {
        self.center = center
        self.userId = userId
        self.now = now
    }

    public func reconcile(_ tasks: [TodoTask]) async {
        let desired = ReminderPlanner.plan(tasks: tasks, userId: userId, now: now())
        let desiredByID = Dictionary(desired.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let pending = await center.pendingReminders()
        let pendingByID = Dictionary(pending.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let obsolete = pending.map(\.id).filter { desiredByID[$0] == nil }
        if !obsolete.isEmpty { await center.cancel(ids: obsolete) }

        lastError = nil
        for reminder in desired where pendingByID[reminder.id] != reminder {
            do {
                try await center.schedule(reminder)  // ten sam identyfikator podmienia stare powiadomienie
            } catch {
                lastError = error
            }
        }
    }
}
