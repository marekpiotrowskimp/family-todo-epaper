import Foundation
import Testing
@testable import TodoCore

/// Notatka zadania: tylko w telefonie, który ją dodał. Nie trafia do protokołu ani na wyświetlacz.
@MainActor
@Suite struct TaskNoteTests {
    let clock = TestClock()

    func makeRepo(user: String = "anna", storage: TaskStorage = InMemoryTaskStorage()) throws -> TaskRepository {
        let clock = self.clock
        return try TaskRepository(userId: user, storage: storage, now: { clock.now }, makeID: sequentialIDs())
    }

    // MARK: - AC-1: tworzenie i odczyt

    @Test func taskWithoutNoteHasEmptyNote() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie")
        #expect(repo.note(id: task.id) == "")
        #expect(repo.note(id: "brak") == "")
    }

    @Test func createStoresNote() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Zakupy", note: "Mleko 2%\nchleb")
        #expect(repo.note(id: task.id) == "Mleko 2%\nchleb")
    }

    // MARK: - AC-2: normalizacja i limit

    @Test func noteIsTrimmedAndLineEndingsNormalized() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Zakupy", note: "  Mleko 2%\r\nchleb\r ser \n\n")
        #expect(repo.note(id: task.id) == "Mleko 2%\nchleb\n ser")
    }

    @Test func noteLimitIs2048BytesInclusive() throws {
        #expect(TaskLimits.maxNoteBytes == 2048)
        let repo = try makeRepo()
        let max = try repo.create(title: "Długa", note: String(repeating: "ą", count: 1024))  // 1024 znaki = 2048 bajtów
        #expect(repo.note(id: max.id).utf8.count == 2048)
        #expect(throws: TaskValidationError.noteTooLong) {
            try repo.create(title: "Za długa", note: String(repeating: "ą", count: 1024) + "a")  // 2049 bajtów
        }
        #expect(repo.allTasks.count == 1)
    }

    @Test func setNoteRejectsTooLongNoteAndKeepsOldOne() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Pranie", note: "60 stopni")
        #expect(throws: TaskValidationError.noteTooLong) {
            try repo.setNote(id: task.id, String(repeating: "ą", count: 1024) + "a")
        }
        #expect(repo.note(id: task.id) == "60 stopni")
    }

    @Test func setNoteOnUnknownTaskThrowsNotFound() throws {
        let repo = try makeRepo()
        try repo.create(title: "Kontrola", note: "x")  // kontrola: notatki działają
        #expect(throws: TaskValidationError.notFound) { try repo.setNote(id: "brak", "x") }
    }

    // MARK: - AC-3: edycja nie jest zmianą zadania

    @Test func settingNoteDoesNotChangeTaskVersionOrPending() throws {
        let others = makeTask("t1", owner: "bartek", created: 500, updated: 1000)
        let storage = InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: [others], pendingIDs: [], cursor: nil))
        let repo = try makeRepo(storage: storage)
        clock.advance(ms: 5000)

        try repo.setNote(id: "t1", "Klucz pod wycieraczką")  // także cudze zadanie

        #expect(repo.note(id: "t1") == "Klucz pod wycieraczką")
        #expect(repo.task(id: "t1") == others)
        #expect(repo.pendingIDs.isEmpty)
    }

    @Test func emptyNoteClearsIt() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Zakupy", note: "Mleko")
        try repo.setNote(id: task.id, " \n ")
        #expect(repo.note(id: task.id) == "")
    }

    // MARK: - AC-4: trwałość i zgodność pliku

    @Test func noteSurvivesNewRepositoryInstance() throws {
        let url = temporaryFileURL()
        let first = try makeRepo(storage: FileTaskStorage(url: url))
        let a = try first.create(title: "Zakupy", note: "Mleko 2%\nchleb")
        let b = try first.create(title: "Pranie")
        try first.setNote(id: b.id, "60 stopni")

        let reopened = try makeRepo(storage: FileTaskStorage(url: url))
        #expect(reopened.note(id: a.id) == "Mleko 2%\nchleb")
        #expect(reopened.note(id: b.id) == "60 stopni")
    }

    /// Plik z obecnej wersji aplikacji nie ma notatek.
    @Test func fileWithoutNotesLoadsWithEmptyNotes() throws {
        let url = temporaryFileURL()
        let legacy = """
            {"tasks":[{"id":"a","ownerId":"anna","title":"Stare","priority":1,"status":"done",\
            "createdAt":-978307199,"updatedAt":-978307195,"updatedBy":"anna","deleted":false}],\
            "pendingIDs":[],"cursor":{"storeId":"S1","revision":7}}
            """
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: url)
        let repo = try makeRepo(storage: FileTaskStorage(url: url))
        #expect(repo.allTasks.map(\.id) == ["a"])
        #expect(repo.note(id: "a") == "")
        try repo.setNote(id: "a", "Nowa")  // plik da się dalej zapisywać z notatką
        #expect(try makeRepo(storage: FileTaskStorage(url: url)).note(id: "a") == "Nowa")
    }

    // MARK: - AC-5: synchronizacja

    @Test func newerRemoteVersionKeepsLocalNote() throws {
        let original = makeTask("t1", updated: 1000)
        let storage = InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: [original], pendingIDs: [], cursor: nil))
        let repo = try makeRepo(storage: storage)
        try repo.setNote(id: "t1", "Moja notatka")

        var remote = original
        remote.title = "Zmienione na innym telefonie"
        remote.updatedAt = ms(2000)
        remote.updatedBy = "bartek"
        #expect(repo.applyRemote([remote]) == ["t1"])

        #expect(repo.task(id: "t1")?.title == "Zmienione na innym telefonie")
        #expect(repo.note(id: "t1") == "Moja notatka")
    }

    @Test func deletingTaskRemovesNote() throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Zakupy", note: "Mleko")
        #expect(repo.note(id: task.id) == "Mleko")  // kontrola
        try repo.delete(id: task.id)
        #expect(repo.note(id: task.id) == "")
    }

    @Test func remoteDeletionRemovesNote() throws {
        let original = makeTask("t1", updated: 1000)
        let storage = InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: [original], pendingIDs: [], cursor: nil))
        let repo = try makeRepo(storage: storage)
        try repo.setNote(id: "t1", "Mleko")
        #expect(repo.note(id: "t1") == "Mleko")  // kontrola

        var tomb = original
        tomb.deleted = true
        tomb.updatedAt = ms(2000)
        tomb.updatedBy = "bartek"
        repo.applyRemote([tomb])
        #expect(repo.note(id: "t1") == "")
    }

    @Test func noteIsNeverSentToDisplay() async throws {
        let repo = try makeRepo()
        let task = try repo.create(title: "Zakupy", note: "TAJNA-NOTATKA")
        #expect(repo.note(id: task.id) == "TAJNA-NOTATKA")  // kontrola: notatka jest w repozytorium
        let link = FakeDeviceLink()
        let engine = SyncEngine(
            repository: repo, link: link,
            credentials: Credentials(userId: "anna", displayName: "Anna", secret: Vectors.secret))

        _ = try await engine.sync()

        #expect(link.pushedTasks.map(\.id) == [task.id])
        let sent = String(decoding: DeviceProtocol.encode(.push(link.pushedTasks)), as: UTF8.self)
        #expect(!sent.contains("TAJNA-NOTATKA"))
        #expect(TaskWire.encode(link.pushedTasks[0]) == TaskWire.encode(task))  // format protokołu bez zmian
    }
}
