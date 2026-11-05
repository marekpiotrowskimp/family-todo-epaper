import Foundation

/// Kursor synchronizacji z konkretnym urządzeniem. Zmiana `storeId` (np. po wyczyszczeniu
/// pamięci ESP32) oznacza, że trzeba wysłać wszystko od nowa.
public struct SyncCursor: Codable, Equatable, Sendable {
    public var storeId: String
    public var revision: UInt32

    public init(storeId: String, revision: UInt32) {
        self.storeId = storeId
        self.revision = revision
    }
}

public struct RepositorySnapshot: Codable, Equatable, Sendable {
    public var tasks: [TodoTask]
    public var pendingIDs: [String]
    public var cursor: SyncCursor?
    /// Czas wykonania zadań (id -> data), tylko lokalnie w telefonie; nie trafia do protokołu.
    /// Brak klucza w starszych plikach = pusty słownik.
    public var completedAt: [String: Date]?

    public init(tasks: [TodoTask], pendingIDs: [String], cursor: SyncCursor?, completedAt: [String: Date]? = nil) {
        self.tasks = tasks
        self.pendingIDs = pendingIDs
        self.cursor = cursor
        self.completedAt = completedAt
    }
}

public protocol TaskStorage {
    func load() throws -> RepositorySnapshot?
    func save(_ snapshot: RepositorySnapshot) throws
}

public final class InMemoryTaskStorage: TaskStorage {
    public private(set) var snapshot: RepositorySnapshot?

    public init(snapshot: RepositorySnapshot? = nil) {
        self.snapshot = snapshot
    }

    public func load() throws -> RepositorySnapshot? {
        snapshot
    }

    public func save(_ snapshot: RepositorySnapshot) throws {
        self.snapshot = snapshot
    }
}

/// Zapis stanu repozytorium do pliku JSON (atomowo).
public final class FileTaskStorage: TaskStorage {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> RepositorySnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(RepositorySnapshot.self, from: Data(contentsOf: url))
    }

    public func save(_ snapshot: RepositorySnapshot) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}

/// Lokalna lista zadań telefonu. Daty są przechowywane w pełnych ms (jak w protokole), żeby
/// porównania z wersjami z urządzenia i z zaplanowanymi powiadomieniami były dokładne.
/// Każda zmiana lokalna ustawia `updatedAt = now()`,
/// `updatedBy = userId`, trafia do `pendingIDs` i jest od razu zapisywana w `storage`.
@MainActor
public final class TaskRepository {
    public let userId: String
    /// Wszystkie rekordy, także tombstone'y.
    public private(set) var allTasks: [TodoTask] = []
    /// Zadania do wysłania na urządzenie przy najbliższej synchronizacji.
    public private(set) var pendingIDs: Set<String> = []
    public private(set) var syncCursor: SyncCursor?
    /// Błąd ostatniego zapisu z operacji, które nie rzucają (scalanie z urządzenia, kursor).
    public private(set) var lastSaveError: Error?

    /// Czas wykonania ukończonych zadań; tylko w telefonie, poza protokołem.
    private var completions: [String: Date] = [:]
    private let storage: TaskStorage
    private let now: () -> Date
    private let makeID: () -> String

    public init(
        userId: String,
        storage: TaskStorage,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) throws {
        self.userId = userId
        self.storage = storage
        self.now = now
        self.makeID = makeID
        if let snapshot = try storage.load() {
            allTasks = snapshot.tasks
            pendingIDs = Set(snapshot.pendingIDs)
            syncCursor = snapshot.cursor
            completions = snapshot.completedAt ?? [:]
        }
    }

    /// Zadania nieusunięte: najpierw aktywne, potem ukończone, w każdej grupie wg `DisplayOrder`.
    public var visibleTasks: [TodoTask] {
        allTasks.filter { !$0.deleted }.sorted { a, b in
            if a.status != b.status { return a.status == .active }
            return DisplayOrder.areInIncreasingOrder(a, b)
        }
    }

    /// Zadania do zrobienia (aktywne, nieusunięte) wg `DisplayOrder`.
    public var activeTasks: [TodoTask] {
        allTasks.filter { !$0.deleted && $0.status == .active }.sorted(by: DisplayOrder.areInIncreasingOrder)
    }

    /// Historia: ukończone, nieusunięte zadania, od ostatnio wykonanego (remis: `id` rosnąco).
    public var history: [HistoryEntry] {
        allTasks.filter { !$0.deleted && $0.status == .done }
            .map { HistoryEntry(task: $0, completedAt: completions[$0.id] ?? $0.updatedAt) }
            .sorted { a, b in
                if a.completedAt != b.completedAt { return a.completedAt > b.completedAt }
                return a.task.id.utf8.lexicographicallyPrecedes(b.task.id.utf8)
            }
    }

    /// Czas wykonania zapisany w telefonie (nil dla zadań aktywnych i nieznanych).
    /// Ukończone zadanie bez zapisanego czasu (plik ze starszej wersji) ma czas swojej wersji.
    public func completedAt(id: String) -> Date? {
        guard let task = task(id: id), task.status == .done else { return nil }
        return completions[id] ?? task.updatedAt
    }

    public func task(id: String) -> TodoTask? {
        allTasks.first { $0.id == id }
    }

    /// Tytuł jest przycinany z białych znaków; pusty -> `.emptyTitle`, > 120 bajtów UTF-8 -> `.titleTooLong`.
    @discardableResult
    public func create(
        title: String,
        priority: Priority = .normal,
        dueAt: Date? = nil,
        reminderAt: Date? = nil
    ) throws -> TodoTask {
        let title = try Self.validatedTitle(title)
        let timestamp = WireTime.wholeMilliseconds(now())
        let task = TodoTask(
            id: makeID(), ownerId: userId, title: title, priority: priority, dueAt: dueAt.map(WireTime.wholeMilliseconds),
            reminderAt: reminderAt.map(WireTime.wholeMilliseconds), createdAt: timestamp, updatedAt: timestamp,
            updatedBy: userId)
        allTasks.append(task)
        pendingIDs.insert(task.id)
        try save()
        return task
    }

    /// Edycja dowolnego zadania (także cudzego). `id`, `ownerId`, `createdAt` pozostają bez zmian.
    @discardableResult
    public func update(id: String, _ change: (inout TodoTask) -> Void) throws -> TodoTask {
        guard let index = index(of: id) else { throw TaskValidationError.notFound }
        let original = allTasks[index]
        var task = original
        change(&task)
        task.id = original.id
        task.ownerId = original.ownerId
        task.createdAt = original.createdAt
        task.title = try Self.validatedTitle(task.title)
        return try commit(task, at: index)
    }

    /// Ponowne ukończenie ukończonego zadania niczego nie zmienia.
    public func complete(id: String) throws {
        guard let index = index(of: id) else { throw TaskValidationError.notFound }
        guard allTasks[index].status != .done else { return }
        var task = allTasks[index]
        task.status = .done
        try commit(task, at: index)
    }

    /// Zamienia zadanie w tombstone. Ponowne usunięcie niczego nie zmienia.
    public func delete(id: String) throws {
        guard let index = index(of: id) else { throw TaskValidationError.notFound }
        guard !allTasks[index].deleted else { return }
        var task = allTasks[index]
        task.deleted = true
        try commit(task, at: index)
    }

    /// Scala rekordy z urządzenia według LWW. Nie oznacza ich jako oczekujących.
    /// Zwraca identyfikatory rekordów, które się zmieniły lub pojawiły.
    @discardableResult
    public func applyRemote(_ tasks: [TodoTask]) -> Set<String> {
        var changed: Set<String> = []
        for remote in tasks {
            if let index = index(of: remote.id) {
                guard LWW.wins(remote, over: allTasks[index]) else { continue }
                recordCompletion(of: remote, replacing: allTasks[index])
                allTasks[index] = remote
                pendingIDs.remove(remote.id)  // lokalna wersja została wyparta, nie ma czego wysyłać
            } else {
                recordCompletion(of: remote, replacing: nil)
                allTasks.append(remote)
            }
            changed.insert(remote.id)
        }
        if !changed.isEmpty { saveRecordingError() }
        return changed
    }

    /// Usuwa z `pendingIDs` zadania, których bieżący `updatedAt` jest równy wysłanej wersji.
    /// Zadanie zmienione w trakcie synchronizacji zostaje oczekujące.
    public func markSynced(_ pushedVersions: [String: Date]) {
        var cleared = false
        for (id, version) in pushedVersions where task(id: id)?.updatedAt == version {
            if pendingIDs.remove(id) != nil { cleared = true }
        }
        if cleared { saveRecordingError() }
    }

    public func setSyncCursor(_ cursor: SyncCursor?) {
        guard cursor != syncCursor else { return }
        syncCursor = cursor
        saveRecordingError()
    }

    // MARK: - Prywatne

    private static func validatedTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TaskValidationError.emptyTitle }
        if trimmed.utf8.count > TaskLimits.maxTitleBytes { throw TaskValidationError.titleTooLong }
        return trimmed
    }

    private func index(of id: String) -> Int? {
        allTasks.firstIndex { $0.id == id }
    }

    @discardableResult
    private func commit(_ task: TodoTask, at index: Int) throws -> TodoTask {
        var task = task
        task.dueAt = task.dueAt.map(WireTime.wholeMilliseconds)
        task.reminderAt = task.reminderAt.map(WireTime.wholeMilliseconds)
        task.updatedAt = WireTime.wholeMilliseconds(now())
        task.updatedBy = userId
        recordCompletion(of: task, replacing: allTasks[index])
        allTasks[index] = task
        pendingIDs.insert(task.id)
        try save()
        return task
    }

    /// Ukończenie zapisuje czas wersji, która je wprowadziła (lokalnie: `now`; z innego telefonu:
    /// jego `updatedAt`). Zadanie już ukończone zachowuje czas, przywrócone go traci.
    private func recordCompletion(of task: TodoTask, replacing previous: TodoTask?) {
        guard task.status == .done else {
            completions[task.id] = nil
            return
        }
        if let previous, previous.status == .done {
            completions[task.id] = completions[task.id] ?? previous.updatedAt
        } else {
            completions[task.id] = task.updatedAt
        }
    }

    private func save() throws {
        try storage.save(RepositorySnapshot(
            tasks: allTasks, pendingIDs: pendingIDs.sorted(), cursor: syncCursor, completedAt: completions))
        lastSaveError = nil
    }

    private func saveRecordingError() {
        do {
            try save()
        } catch {
            lastSaveError = error
        }
    }
}
