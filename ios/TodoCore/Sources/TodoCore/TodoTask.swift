import Foundation

public enum Priority: Int, Codable, Sendable, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
}

public enum TaskStatus: String, Codable, Sendable {
    case active
    case done
}

/// Zadanie w formie wspólnej dla telefonu i ESP32. Czasy są przesyłane jako milisekundy od epoki Unix.
public struct TodoTask: Hashable, Codable, Sendable {
    public var id: String
    public var ownerId: String
    public var title: String
    public var priority: Priority
    public var dueAt: Date?
    public var status: TaskStatus
    public var reminderAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    /// userId autora ostatniej zmiany; rozstrzyga remis `updatedAt` w LWW.
    public var updatedBy: String
    /// Tombstone: usunięte zadanie zostaje jako rekord, żeby usunięcie dotarło do innych telefonów.
    public var deleted: Bool

    public init(
        id: String,
        ownerId: String,
        title: String,
        priority: Priority = .normal,
        dueAt: Date? = nil,
        status: TaskStatus = .active,
        reminderAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        updatedBy: String,
        deleted: Bool = false
    ) {
        self.id = id
        self.ownerId = ownerId
        self.title = title
        self.priority = priority
        self.dueAt = dueAt
        self.status = status
        self.reminderAt = reminderAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.deleted = deleted
    }
}

public enum TaskLimits {
    /// Ta sama granica co `kMaxTitleBytes` w firmware.
    public static let maxTitleBytes = 120
    /// Notatka (tylko w telefonie, nie trafia do protokołu): min. 1024 znaki także po polsku.
    public static let maxNoteBytes = 2048
}

public enum TaskValidationError: Error, Equatable {
    case emptyTitle
    case titleTooLong
    case noteTooLong
    case notFound
}
