import Foundation
import Testing
@testable import TodoCore

/// Historia zadań: ukończenie przenosi zadanie z listy „Do zrobienia” do historii
/// i zapisuje w telefonie moment wykonania.
@MainActor
@Suite struct TaskHistoryTests {
    let clock = TestClock()

    func makeRepo(user: String = "anna", storage: TaskStorage = InMemoryTaskStorage()) throws -> TaskRepository {
        let clock = self.clock
        return try TaskRepository(userId: user, storage: storage, now: { clock.now }, makeID: sequentialIDs())
    }

    func seeded(_ tasks: [TodoTask], completedAt: [String: Date]? = nil) -> InMemoryTaskStorage {
        InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: tasks, pendingIDs: [], cursor: nil, completedAt: completedAt))
    }

    // MARK: - Ukończenie przenosi do historii

    @Test func completingMovesTaskFromActiveListToHistoryWithCompletionTime() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        #expect(repo.activeTasks.map(\.id) == [task.id])
        #expect(repo.history.isEmpty)

        clock.advance(ms: 60_000)
        try repo.complete(id: task.id)
        let done = try #require(repo.task(id: task.id))

        #expect(repo.activeTasks.isEmpty)
        #expect(repo.history == [HistoryEntry(task: done, completedAt: ms(1_793_430_060_000))])
        #expect(repo.completedAt(id: task.id) == ms(1_793_430_060_000))
    }

    @Test func completingAgainKeepsFirstCompletionTime() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        clock.advance(ms: 5000)
        try repo.complete(id: task.id)
        #expect(repo.completedAt(id: task.id) == ms(1_793_430_001_000))
    }

    @Test func historyListsNewestCompletionFirstWithoutActiveOrDeleted() throws {
        let repo = try makeRepo()
        let first = try repo.create(title: "Pierwsze")
        let second = try repo.create(title: "Drugie")
        let stays = try repo.create(title: "Aktywne")
        let gone = try repo.create(title: "Usunięte")
        clock.advance(ms: 1000)
        try repo.complete(id: first.id)
        clock.advance(ms: 1000)
        try repo.complete(id: second.id)
        try repo.complete(id: gone.id)
        clock.advance(ms: 1000)
        try repo.delete(id: gone.id)

        #expect(repo.history.map(\.task.id) == [second.id, first.id])
        #expect(repo.history.map(\.completedAt) == [ms(1_793_430_002_000), ms(1_793_430_001_000)])
        #expect(repo.activeTasks.map(\.id) == [stays.id])
    }

    @Test func historyTieOnCompletionTimeIsOrderedById() throws {
        let tasks = [makeTask("b", status: .done), makeTask("a", status: .done)]
        let repo = try makeRepo(storage: seeded(tasks, completedAt: ["a": ms(5000), "b": ms(5000)]))
        #expect(repo.history.map(\.task.id) == ["a", "b"])
    }

    @Test func activeTasksExcludeDoneAndDeletedAndKeepDisplayOrder() throws {
        let tasks = [
            makeTask("done_high", priority: .high, status: .done),
            makeTask("low", priority: .low),
            makeTask("gone", priority: .high, deleted: true),
            makeTask("high_due", priority: .high, due: 1000),
            makeTask("normal", priority: .normal),
        ]
        let repo = try makeRepo(storage: seeded(tasks))
        #expect(repo.activeTasks.map(\.id) == ["high_due", "normal", "low"])
    }

    // MARK: - Przywrócenie i edycja

    @Test func reopeningRemovesFromHistoryAndCompletingAgainRecordsNewTime() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        clock.advance(ms: 1000)
        try repo.update(id: task.id) { $0.status = .active }

        #expect(repo.history.isEmpty)
        #expect(repo.completedAt(id: task.id) == nil)
        #expect(repo.activeTasks.map(\.id) == [task.id])

        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        #expect(repo.completedAt(id: task.id) == ms(1_793_430_003_000))
    }

    @Test func editingDoneTaskKeepsCompletionTime() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        clock.advance(ms: 1000)
        try repo.update(id: task.id) { $0.title = "Pranie i suszenie" }

        let entry = try #require(repo.history.first)
        #expect(entry.task.title == "Pranie i suszenie")
        #expect(entry.task.updatedAt == ms(1_793_430_002_000))
        #expect(entry.completedAt == ms(1_793_430_001_000))
    }

    // MARK: - Zmiany z innych telefonów (przez wyświetlacz)

    @Test func remoteCompletionUsesVersionTimeOfThatChange() throws {
        let repo = try makeRepo(storage: seeded([makeTask("a", updated: 1000)]))
        repo.applyRemote([makeTask("a", updated: 7000, by: "bartek", status: .done)])
        #expect(repo.completedAt(id: "a") == ms(7000))
        #expect(repo.history.map(\.task.id) == ["a"])
    }

    @Test func unknownRemoteDoneTaskEntersHistoryWithItsVersionTime() throws {
        let repo = try makeRepo()
        repo.applyRemote([makeTask("z", owner: "bartek", updated: 9000, status: .done)])
        #expect(repo.history == [HistoryEntry(task: makeTask("z", owner: "bartek", updated: 9000, status: .done), completedAt: ms(9000))])
    }

    @Test func remoteEditOfAlreadyDoneTaskKeepsLocalCompletionTime() throws {
        let repo = try makeRepo(storage: seeded([makeTask("a", updated: 4000, status: .done)], completedAt: ["a": ms(3000)]))
        var edited = makeTask("a", updated: 8000, by: "bartek", status: .done)
        edited.title = "Nowy tytuł"
        repo.applyRemote([edited])
        #expect(repo.completedAt(id: "a") == ms(3000))
        #expect(repo.history.first?.task.title == "Nowy tytuł")
    }

    @Test func remoteReopenRemovesFromHistory() throws {
        let repo = try makeRepo(storage: seeded([makeTask("a", updated: 4000, status: .done)], completedAt: ["a": ms(3000)]))
        repo.applyRemote([makeTask("a", updated: 8000, by: "bartek", status: .active)])
        #expect(repo.history.isEmpty)
        #expect(repo.completedAt(id: "a") == nil)
        #expect(repo.activeTasks.map(\.id) == ["a"])
    }

    @Test func olderRemoteVersionDoesNotChangeCompletionTime() throws {
        let repo = try makeRepo(storage: seeded([makeTask("a", updated: 4000, status: .done)], completedAt: ["a": ms(3000)]))
        repo.applyRemote([makeTask("a", updated: 2000, by: "bartek", status: .active)])
        #expect(repo.completedAt(id: "a") == ms(3000))
    }

    // MARK: - Trwałość i protokół

    @Test func completionTimeSurvivesNewRepositoryInstance() throws {
        let url = temporaryFileURL()
        let first = try makeRepo(storage: FileTaskStorage(url: url))
        let task = try first.create(title: "Pranie")
        clock.advance(ms: 1000)
        try first.complete(id: task.id)

        let second = try makeRepo(storage: FileTaskStorage(url: url))
        #expect(second.completedAt(id: task.id) == ms(1_793_430_001_000))
        #expect(second.history.map(\.completedAt) == [ms(1_793_430_001_000)])
    }

    @Test func doneTaskFromFileWithoutCompletionTimesUsesItsVersionTime() throws {
        let url = temporaryFileURL()
        let legacy = """
            {"tasks":[{"id":"a","ownerId":"anna","title":"Stare","priority":1,"status":"done",\
            "createdAt":-978307199,"updatedAt":-978307195,"updatedBy":"anna","deleted":false}],\
            "pendingIDs":[]}
            """
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: url)
        let repo = try makeRepo(storage: FileTaskStorage(url: url))
        // Date koduje się domyślnie jako sekundy od 2001-01-01: -978307195 s = 5 s od epoki Unix.
        #expect(repo.history.map(\.completedAt) == [ms(5000)])
        #expect(repo.completedAt(id: "a") == ms(5000))
    }

    @Test func completionTimeIsNotSentToDevice() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        let done = try #require(repo.task(id: task.id))
        let keys = Set(TaskWire.jsonObject(done).keys)
        #expect(keys == ["id", "owner", "title", "prio", "status", "created", "updated", "by", "del"])
        #expect(repo.completedAt(id: task.id) == ms(1_793_430_001_000))  // jest tylko w telefonie
    }

}

/// Etykieta „kiedy wykonano” w wierszu historii.
@Suite struct HistoryFormatTests {
    static let warsaw: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    static func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        warsaw.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    @Test(arguments: [
        (at(2026, 11, 5, 14, 32), "dziś, 14:32"),
        (at(2026, 11, 5, 0, 0), "dziś, 0:00"),
        (at(2026, 11, 4, 9, 5), "wczoraj, 9:05"),
        (at(2026, 11, 4, 23, 59), "wczoraj, 23:59"),
        (at(2026, 11, 3, 14, 32), "03.11, 14:32"),
        (at(2026, 1, 1, 8, 0), "01.01, 8:00"),
        (at(2025, 12, 31, 21, 7), "31.12.2025, 21:07"),
    ])
    func completedLabelIsRelativeToToday(date: Date, expected: String) {
        let now = Self.at(2026, 11, 5, 18, 0)
        #expect(HistoryFormat.completedLabel(date, now: now, calendar: Self.warsaw) == expected)
    }

    @Test func completedLabelUsesCalendarTimeZone() {
        // 2026-11-04 23:30 UTC to już 5 listopada 0:30 w Warszawie.
        let utcLate = Date(timeIntervalSince1970: 1_793_835_000)
        #expect(HistoryFormat.completedLabel(utcLate, now: Self.at(2026, 11, 5, 18, 0), calendar: Self.warsaw) == "dziś, 0:30")
    }
}
