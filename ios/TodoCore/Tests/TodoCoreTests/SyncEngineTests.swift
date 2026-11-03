import Foundation
import Testing
@testable import TodoCore

@MainActor
@Suite struct SyncEngineTests {
    let link = FakeDeviceLink()
    let credentials = Credentials(userId: "anna", displayName: "Anna", secret: Vectors.secret)

    func makeRepo(tasks: [TodoTask], pending: [String], cursor: SyncCursor?) throws -> TaskRepository {
        try TaskRepository(
            userId: "anna",
            storage: InMemoryTaskStorage(snapshot: RepositorySnapshot(tasks: tasks, pendingIDs: pending, cursor: cursor)),
            now: { ms(9_000_000) },
            makeID: sequentialIDs())
    }

    func engine(_ repo: TaskRepository) -> SyncEngine {
        SyncEngine(repository: repo, link: link, credentials: credentials)
    }

    let synced = makeTask("synced", updated: 1000)
    let pendingA = makeTask("a", updated: 2000)
    let pendingB = makeTask("b", updated: 2100)

    @Test func happyPathPushesPendingPullsChangesAndDisconnects() async throws {
        let repo = try makeRepo(
            tasks: [synced, pendingA, pendingB], pending: ["a", "b"], cursor: SyncCursor(storeId: "S1", revision: 5))
        let remote = makeTask("r", owner: "bartek", updated: 3000)
        link.helloResponse = DeviceHello(nonce: Vectors.nonce, storeId: "S1", revision: 5)
        link.pages[5] = DevicePull(storeId: "S1", revision: 8, tasks: [remote], more: false)

        let report = try await engine(repo).sync()

        #expect(link.calls == ["connect", "hello", "auth", "push", "pull", "disconnect"])
        #expect(Set(link.pushedTasks.map(\.id)) == ["a", "b"])
        #expect(link.pullRequests.map(\.since) == [5])
        #expect(repo.pendingIDs.isEmpty)
        #expect(repo.syncCursor == SyncCursor(storeId: "S1", revision: 8))
        #expect(repo.task(id: "r") == remote)
        #expect(report == SyncReport(pushedIDs: ["a", "b"], pulledChangedIDs: ["r"], rejectedIDs: []))
    }

    @Test func authenticatesWithSharedVectorMac() async throws {
        let repo = try makeRepo(tasks: [], pending: [], cursor: SyncCursor(storeId: "S1", revision: 0))
        _ = try await engine(repo).sync()
        #expect(link.receivedMacs.map(\.hex) == [Vectors.annaMacHex])
    }

    @Test func authenticationIntroducesPhoneWithDisplayName() async throws {
        let repo = try makeRepo(tasks: [], pending: [], cursor: SyncCursor(storeId: "S1", revision: 0))
        _ = try await engine(repo).sync()
        #expect(link.receivedNames == ["Anna"])
        #expect(link.receivedMacs.map(\.hex) == [Vectors.annaMacHex])
    }

    @Test func retryAfterInterruptedPushSendsEachTaskExactlyOnce() async throws {
        let repo = try makeRepo(tasks: [pendingA, pendingB], pending: ["a", "b"], cursor: SyncCursor(storeId: "S1", revision: 5))
        link.failOn = .push
        await #expect(throws: SyncError.transport("push")) { try await engine(repo).sync() }
        link.failOn = nil
        _ = try await engine(repo).sync()
        #expect(link.pushedTasks.map(\.id).sorted() == ["a", "b"])
    }

    @Test func pullPageFromDifferentStoreIsRejectedWithoutMovingCursor() async throws {
        let cursor = SyncCursor(storeId: "S1", revision: 5)
        let repo = try makeRepo(tasks: [], pending: [], cursor: cursor)
        let stranger = makeTask("x", owner: "obcy")
        link.pages[5] = DevicePull(storeId: "INNY", revision: 9, tasks: [stranger], more: false)
        await #expect(throws: SyncError.malformedResponse) { try await engine(repo).sync() }
        #expect(repo.syncCursor == cursor)
        #expect(repo.task(id: "x") == nil)
        #expect(link.disconnectCount == 1)
    }

    @Test func nothingPendingSkipsPush() async throws {
        let repo = try makeRepo(tasks: [synced], pending: [], cursor: SyncCursor(storeId: "S1", revision: 3))
        _ = try await engine(repo).sync()
        #expect(link.calls == ["connect", "hello", "auth", "pull", "disconnect"])
    }

    @Test func rejectedAuthStopsSyncWithoutChanges() async throws {
        let cursor = SyncCursor(storeId: "S1", revision: 5)
        let repo = try makeRepo(tasks: [pendingA], pending: ["a"], cursor: cursor)
        link.acceptedMac = Data(repeating: 0, count: 32)
        await #expect(throws: SyncError.unauthorized) { try await engine(repo).sync() }
        #expect(link.calls == ["connect", "hello", "auth", "disconnect"])
        #expect(repo.pendingIDs == ["a"])
        #expect(repo.syncCursor == cursor)
    }

    @Test func interruptedPushKeepsPendingAndRetrySendsSameVersions() async throws {
        let cursor = SyncCursor(storeId: "S1", revision: 5)
        let repo = try makeRepo(tasks: [pendingA, pendingB], pending: ["a", "b"], cursor: cursor)
        link.failOn = .push
        await #expect(throws: SyncError.transport("push")) { try await engine(repo).sync() }
        #expect(repo.pendingIDs == ["a", "b"])
        #expect(repo.syncCursor == cursor)
        #expect(link.disconnectCount == 1)
        #expect(repo.task(id: "a")?.updatedAt == pendingA.updatedAt)  // zapisana wersja się nie zmieniła

        link.failOn = nil
        _ = try await engine(repo).sync()
        #expect(Set(link.pushedTasks) == [pendingA, pendingB])
        #expect(repo.pendingIDs.isEmpty)
        #expect(link.disconnectCount == 2)
    }

    @Test func interruptedPullKeepsProgressOfCompletedPages() async throws {
        let repo = try makeRepo(tasks: [pendingA], pending: ["a"], cursor: SyncCursor(storeId: "S1", revision: 0))
        let r1 = makeTask("r1", owner: "bartek", updated: 3000)
        link.pages[0] = DevicePull(storeId: "S1", revision: 20, tasks: [r1], more: true)
        link.failOnPullSince = 20
        await #expect(throws: SyncError.transport("pull")) { try await engine(repo).sync() }
        #expect(repo.pendingIDs.isEmpty)  // push potwierdzony przez urządzenie
        #expect(repo.task(id: "r1") == r1)
        #expect(repo.syncCursor == SyncCursor(storeId: "S1", revision: 20))
        #expect(link.disconnectCount == 1)
    }

    @Test func pullFollowsPagesUntilNoMore() async throws {
        let repo = try makeRepo(tasks: [], pending: [], cursor: SyncCursor(storeId: "S1", revision: 0))
        let r1 = makeTask("r1", owner: "bartek")
        let r2 = makeTask("r2", owner: "celina")
        link.pages[0] = DevicePull(storeId: "S1", revision: 20, tasks: [r1], more: true)
        link.pages[20] = DevicePull(storeId: "S1", revision: 23, tasks: [r2], more: false)
        let report = try await engine(repo).sync()
        #expect(link.pullRequests.map(\.since) == [0, 20])
        #expect(link.pullRequests.map(\.limit) == [SyncLimits.batchSize, SyncLimits.batchSize])
        #expect(repo.syncCursor == SyncCursor(storeId: "S1", revision: 23))
        #expect(report.pulledChangedIDs == ["r1", "r2"])
    }

    @Test func pushIsSplitIntoBatchesOfTwenty() async throws {
        let tasks = (0..<45).map { makeTask("t\($0)", updated: 2000) }
        let repo = try makeRepo(tasks: tasks, pending: tasks.map(\.id), cursor: SyncCursor(storeId: "S1", revision: 0))
        _ = try await engine(repo).sync()
        #expect(link.pushedBatches.map(\.count) == [20, 20, 5])
        #expect(Set(link.pushedTasks.map(\.id)) == Set(tasks.map(\.id)))
    }

    @Test func changedStoreIDTriggersFullPushAndPullFromZero() async throws {
        let tomb = makeTask("gone", updated: 1500, deleted: true)
        let repo = try makeRepo(
            tasks: [synced, pendingA, tomb], pending: ["a"], cursor: SyncCursor(storeId: "OLD", revision: 9))
        link.helloResponse = DeviceHello(nonce: Vectors.nonce, storeId: "NEW", revision: 0)
        link.pages[0] = DevicePull(storeId: "NEW", revision: 3, tasks: [], more: false)
        _ = try await engine(repo).sync()
        #expect(Set(link.pushedTasks.map(\.id)) == ["synced", "a", "gone"])
        #expect(link.pullRequests.map(\.since) == [0])
        #expect(repo.syncCursor == SyncCursor(storeId: "NEW", revision: 3))
    }

    @Test func firstSyncWithoutCursorPushesEverything() async throws {
        let repo = try makeRepo(tasks: [synced, pendingA], pending: ["a"], cursor: nil)
        _ = try await engine(repo).sync()
        #expect(Set(link.pushedTasks.map(\.id)) == ["synced", "a"])
        #expect(link.pullRequests.map(\.since) == [0])
        #expect(repo.syncCursor == SyncCursor(storeId: "S1", revision: 0))
    }

    @Test func rejectedFullStaysPendingRejectedInvalidIsDropped() async throws {
        let bad = makeTask("bad", updated: 2000)
        let repo = try makeRepo(
            tasks: [pendingA, pendingB, bad], pending: ["a", "b", "bad"], cursor: SyncCursor(storeId: "S1", revision: 0))
        link.outcome = { task in
            switch task.id {
            case "b": return .rejectedFull
            case "bad": return .rejectedInvalid
            default: return .inserted
            }
        }
        let report = try await engine(repo).sync()
        #expect(repo.pendingIDs == ["b"])
        #expect(report.rejectedIDs == ["b", "bad"])
        #expect(report.pushedIDs == ["a"])
    }

    @Test func editMadeDuringSyncStaysPending() async throws {
        let repo = try makeRepo(tasks: [pendingA], pending: ["a"], cursor: SyncCursor(storeId: "S1", revision: 0))
        link.onPush = { _ in
            _ = try? repo.update(id: "a") { $0.title = "Zmienione w trakcie" }
        }
        _ = try await engine(repo).sync()
        #expect(link.pushedTasks.map(\.title) == [pendingA.title])
        #expect(repo.pendingIDs == ["a"])
        #expect(repo.task(id: "a")?.title == "Zmienione w trakcie")
    }
}
