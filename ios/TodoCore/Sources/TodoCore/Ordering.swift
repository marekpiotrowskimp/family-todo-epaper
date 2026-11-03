import Foundation

/// Last-writer-wins, identycznie jak `todo::wins` w firmware.
public enum LWW {
    /// `true`, gdy `incoming` ma nowszy `updatedAt`, a przy remisie większy `updatedBy`
    /// (porównanie bajtów UTF-8). Ta sama wersja zwraca `false`.
    public static func wins(_ incoming: TodoTask, over current: TodoTask) -> Bool {
        let a = WireTime.milliseconds(incoming.updatedAt)
        let b = WireTime.milliseconds(current.updatedAt)
        if a != b { return a > b }
        return current.updatedBy.utf8.lexicographicallyPrecedes(incoming.updatedBy.utf8)
    }
}

/// Globalna kolejność listy, identyczna jak `todo::displayBefore` w firmware: priorytet malejąco,
/// zadania z terminem przed zadaniami bez terminu, termin rosnąco, `createdAt` rosnąco, `id` rosnąco.
public enum DisplayOrder {
    public static func areInIncreasingOrder(_ a: TodoTask, _ b: TodoTask) -> Bool {
        if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
        switch (a.dueAt, b.dueAt) {
        case (.some, .none): return true
        case (.none, .some): return false
        case let (.some(x), .some(y)) where x != y: return x < y
        default: break
        }
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.id.utf8.lexicographicallyPrecedes(b.id.utf8)
    }
}
