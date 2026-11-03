import Foundation
import Testing
@testable import TodoCore

@MainActor
@Suite struct TaskDraftTests {
    @Test func draftCopiesEditableFields() {
        let task = makeTask("t1", priority: .high, due: 5000, reminder: 4000)
        #expect(TaskDraft(task) == TaskDraft(title: "Zadanie t1", priority: .high, dueAt: ms(5000), reminderAt: ms(4000)))
    }

    @Test func applyChangesOnlyEditableFields() {
        var task = makeTask("t1", priority: .low, status: .done)
        let draft = TaskDraft(title: "Nowy", priority: .high, dueAt: ms(7000), reminderAt: nil)
        draft.apply(to: &task)
        #expect(task.title == "Nowy")
        #expect(task.priority == .high)
        #expect(task.dueAt == ms(7000))
        #expect(task.reminderAt == nil)
        #expect(task.status == .done)
        #expect(task.deleted == false)
        #expect(task.ownerId == "anna")
    }

    /// Formularz otwarty na starej kopii; w tle synchronizacja oznaczyła zadanie jako zrobione.
    @Test func savingFormDoesNotUndoCompletionFromSync() throws {
        let clock = TestClock(1_000_000)
        let original = makeTask("t1", updated: 1000)
        let storage = InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: [original], pendingIDs: [], cursor: nil))
        let repo = try TaskRepository(userId: "anna", storage: storage, now: { clock.now }, makeID: sequentialIDs())
        var draft = TaskDraft(original)  // otwarcie formularza

        var doneRemotely = original
        doneRemotely.status = .done
        doneRemotely.updatedAt = ms(2000)
        doneRemotely.updatedBy = "bartek"
        repo.applyRemote([doneRemotely])

        draft.title = "Poprawiony tytuł"
        let saved = try repo.update(id: "t1") { draft.apply(to: &$0) }
        #expect(saved.title == "Poprawiony tytuł")
        #expect(saved.status == .done)
    }
}
