import Foundation

/// Pola edytowane w formularzu. Zapis przez `apply(to:)` nie nadpisuje statusu ani usunięcia,
/// które mogły w międzyczasie przyjść z synchronizacji.
public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var priority: Priority
    public var dueAt: Date?
    public var reminderAt: Date?

    public init(title: String, priority: Priority, dueAt: Date?, reminderAt: Date?) {
        self.title = title
        self.priority = priority
        self.dueAt = dueAt
        self.reminderAt = reminderAt
    }

    public init(_ task: TodoTask) {
        self.init(title: task.title, priority: task.priority, dueAt: task.dueAt, reminderAt: task.reminderAt)
    }

    public func apply(to task: inout TodoTask) {
        task.title = title
        task.priority = priority
        task.dueAt = dueAt
        task.reminderAt = reminderAt
    }
}
