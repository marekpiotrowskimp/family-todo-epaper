import Foundation
import Testing
@testable import TodoCore

@MainActor
@Suite struct TaskRepositoryTests {
    let clock = TestClock()

    func makeRepo(user: String = "anna", storage: TaskStorage = InMemoryTaskStorage()) throws -> TaskRepository {
        let clock = self.clock
        return try TaskRepository(userId: user, storage: storage, now: { clock.now }, makeID: sequentialIDs())
    }

    @Test func createFillsAllFieldsAndMarksPending() throws {
        let repo = try makeRepo()
        let task = try repo.create(
            title: "  Kupić mleko \n", priority: .high, dueAt: ms(1_793_520_000_000), reminderAt: ms(1_793_516_400_000))
        let expected = TodoTask(
            id: "id-1", ownerId: "anna", title: "Kupić mleko", priority: .high, dueAt: ms(1_793_520_000_000),
            status: .active, reminderAt: ms(1_793_516_400_000), createdAt: clock.now, updatedAt: clock.now,
            updatedBy: "anna", deleted: false)
        #expect(task == expected)
        #expect(repo.task(id: "id-1") == expected)
        #expect(repo.visibleTasks == [expected])
        #expect(repo.pendingIDs == ["id-1"])
    }

    @Test func storedDatesAreWholeMilliseconds() throws {
        clock.now = ms(1_793_430_000_000).addingTimeInterval(0.0003)
        let repo = try makeRepo()
        let task = try repo.create(
            title: "Pranie",
            dueAt: ms(1_793_520_000_000).addingTimeInterval(0.0002),
            reminderAt: ms(1_793_516_400_000).addingTimeInterval(0.0004))
        #expect(task.createdAt == ms(1_793_430_000_000))
        #expect(task.updatedAt == ms(1_793_430_000_000))
        #expect(task.dueAt == ms(1_793_520_000_000))
        #expect(task.reminderAt == ms(1_793_516_400_000))

        clock.now = ms(1_793_430_001_000).addingTimeInterval(0.0001)
        let edited = try repo.update(id: task.id) { $0.reminderAt = ms(1_793_516_500_000).addingTimeInterval(0.0003) }
        #expect(edited.updatedAt == ms(1_793_430_001_000))
        #expect(edited.reminderAt == ms(1_793_516_500_000))
    }

    @Test func createValidatesTitle() throws {
        let repo = try makeRepo()
        #expect(throws: TaskValidationError.emptyTitle) { try repo.create(title: "   \n") }
        #expect(throws: TaskValidationError.titleTooLong) {
            try repo.create(title: String(repeating: "ą", count: 60) + "a")  // 121 bajtów
        }
        let max = try repo.create(title: String(repeating: "ą", count: 60))  // dokładnie 120 bajtów
        #expect(max.title.utf8.count == 120)
        #expect(repo.allTasks.count == 1)
    }

    @Test func updateBumpsVersionKeepsIdentityAndAllowsEditingOthersTasks() throws {
        let annas = makeTask("t1", owner: "anna", created: 500, updated: 1000)
        let storage = InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: [annas], pendingIDs: [], cursor: nil))
        let repo = try makeRepo(user: "bartek", storage: storage)
        clock.advance(ms: 60_000)
        let updated = try repo.update(id: "t1") {
            $0.title = "Nowy tytuł"
            $0.priority = .low
            $0.id = "podmiana"
            $0.ownerId = "bartek"
            $0.createdAt = ms(1)
        }
        #expect(updated.id == "t1")
        #expect(updated.ownerId == "anna")
        #expect(updated.createdAt == ms(500))
        #expect(updated.title == "Nowy tytuł")
        #expect(updated.priority == .low)
        #expect(updated.updatedAt == clock.now)
        #expect(updated.updatedBy == "bartek")
        #expect(repo.task(id: "t1") == updated)
        #expect(repo.pendingIDs == ["t1"])
    }

    @Test func updateRejectsUnknownIDAndInvalidTitleWithoutChanges() throws {
        let repo = try makeRepo()
        let original = try repo.create(title: "Pranie")
        #expect(throws: TaskValidationError.notFound) { try repo.update(id: "brak") { $0.title = "x" } }
        clock.advance(ms: 1000)
        #expect(throws: TaskValidationError.emptyTitle) { try repo.update(id: original.id) { $0.title = "  " } }
        #expect(repo.task(id: original.id) == original)
    }

    @Test func completeMarksDoneOnce() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        let done = try #require(repo.task(id: task.id))
        #expect(done.status == .done)
        #expect(done.updatedAt == clock.now)
        clock.advance(ms: 1000)
        try repo.complete(id: task.id)
        #expect(repo.task(id: task.id) == done)
    }

    @Test func deleteLeavesTombstoneHiddenFromList() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        repo.markSynced([task.id: task.updatedAt])
        #expect(repo.pendingIDs.isEmpty)
        clock.advance(ms: 1000)
        try repo.delete(id: task.id)
        let tomb = try #require(repo.task(id: task.id))
        #expect(tomb.deleted)
        #expect(tomb.updatedAt == clock.now)
        #expect(repo.visibleTasks.isEmpty)
        #expect(repo.allTasks.map(\.id) == [task.id])
        #expect(repo.pendingIDs == [task.id])
        clock.advance(ms: 1000)
        try repo.delete(id: task.id)
        #expect(repo.task(id: task.id) == tomb)
    }

    @Test func visibleTasksListActiveFirstThenDoneEachInDisplayOrder() throws {
        let tasks = [
            makeTask("done_high", priority: .high, status: .done),
            makeTask("low", priority: .low),
            makeTask("gone", priority: .high, deleted: true),
            makeTask("high_due", priority: .high, due: 1000),
            makeTask("done_low", priority: .low, status: .done),
        ]
        let repo = try makeRepo(storage: InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: tasks, pendingIDs: [], cursor: nil)))
        #expect(repo.visibleTasks.map(\.id) == ["high_due", "low", "done_high", "done_low"])
    }

    @Test func applyRemoteMergesByLWWWithoutMarkingPending() throws {
        let local = [makeTask("a", updated: 2000), makeTask("b", updated: 2000)]
        let repo = try makeRepo(storage: InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: local, pendingIDs: [], cursor: nil)))
        var newerA = makeTask("a", updated: 3000, by: "bartek")
        newerA.title = "od Bartka"
        var olderB = makeTask("b", updated: 1000, by: "bartek")
        olderB.title = "stare"
        let newC = makeTask("c", owner: "bartek", updated: 1500)
        let changed = repo.applyRemote([newerA, olderB, newC])
        #expect(changed == ["a", "c"])
        #expect(repo.task(id: "a") == newerA)
        #expect(repo.task(id: "b") == local[1])
        #expect(repo.task(id: "c") == newC)
        #expect(repo.pendingIDs.isEmpty)
    }

    @Test func applyRemoteDoesNotOverrideNewerLocalEdit() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Lokalnie")
        var stale = task
        stale.title = "Z urządzenia"
        stale.updatedAt = task.updatedAt.addingTimeInterval(-60)
        #expect(repo.applyRemote([stale]).isEmpty)
        #expect(repo.task(id: task.id)?.title == "Lokalnie")
        #expect(repo.pendingIDs == [task.id])
    }

    @Test func markSyncedClearsOnlyMatchingVersions() throws {
        let repo = try makeRepo()
        let a = try repo.create(title: "A")
        let b = try repo.create(title: "B")
        let pushedB = b.updatedAt
        clock.advance(ms: 1000)
        try repo.update(id: b.id) { $0.title = "B2" }  // zmiana w trakcie synchronizacji
        repo.markSynced([a.id: a.updatedAt, b.id: pushedB])
        #expect(repo.pendingIDs == [b.id])
    }

    @Test func stateSurvivesNewRepositoryInstance() throws {
        let url = temporaryFileURL()
        let first = try makeRepo(storage: FileTaskStorage(url: url))
        let a = try first.create(title: "Kupić mleko", priority: .high, dueAt: ms(1_793_520_000_000))
        let b = try first.create(title: "Pranie")
        first.markSynced([a.id: a.updatedAt])
        first.setSyncCursor(SyncCursor(storeId: "S1", revision: 42))
        try first.delete(id: b.id)

        let second = try makeRepo(storage: FileTaskStorage(url: url))
        #expect(second.allTasks.count == 2)
        #expect(second.task(id: a.id) == first.task(id: a.id))
        #expect(second.task(id: b.id)?.deleted == true)
        #expect(second.pendingIDs == [b.id])
        #expect(second.syncCursor == SyncCursor(storeId: "S1", revision: 42))
    }

    @Test func missingFileStartsEmptyButCorruptedFileFails() throws {
        let fresh = try makeRepo(storage: FileTaskStorage(url: temporaryFileURL()))
        #expect(fresh.allTasks.isEmpty)
        #expect(fresh.syncCursor == nil)

        let url = temporaryFileURL()
        let control = try makeRepo(storage: FileTaskStorage(url: url))
        try control.create(title: "Kontrola")
        #expect(FileManager.default.fileExists(atPath: url.path))  // kontrola: zapis trafia do pliku

        try Data("śmieci".utf8).write(to: url)
        #expect(throws: (any Error).self) { try makeRepo(storage: FileTaskStorage(url: url)) }
    }

    /// Charakteryzacja: plik zapisany przez obecną wersję aplikacji (bez czasów wykonania) nadal się wczytuje.
    @Test func fileFromCurrentAppVersionStillLoads() throws {
        let url = temporaryFileURL()
        let legacy = """
            {"tasks":[{"id":"a","ownerId":"anna","title":"Stare","priority":1,"status":"done",\
            "createdAt":-978307199,"updatedAt":-978307195,"updatedBy":"anna","deleted":false},\
            {"id":"b","ownerId":"bartek","title":"Nowe","priority":2,"status":"active",\
            "createdAt":-978307199,"updatedAt":-978307199,"updatedBy":"bartek","deleted":false}],\
            "pendingIDs":["b"],"cursor":{"storeId":"S1","revision":7}}
            """
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: url)
        let repo = try makeRepo(storage: FileTaskStorage(url: url))
        #expect(repo.visibleTasks.map(\.id) == ["b", "a"])
        #expect(repo.task(id: "a")?.updatedAt == ms(5000))
        #expect(repo.pendingIDs == ["b"])
        #expect(repo.syncCursor == SyncCursor(storeId: "S1", revision: 7))
    }
}
