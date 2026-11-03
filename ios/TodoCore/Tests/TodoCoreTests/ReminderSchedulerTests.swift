import Foundation
import Testing
@testable import TodoCore

@MainActor
@Suite struct ReminderSchedulerTests {
    let now = ms(1_000_000)

    @Test func planIncludesOnlyOwnActiveFutureRemindersSortedByTime() {
        let tasks = [
            makeTask("later", owner: "anna", reminder: 3_000_000),
            makeTask("soon", owner: "anna", reminder: 2_000_000),
            makeTask("bartka", owner: "bartek", reminder: 2_000_000),
            makeTask("past", owner: "anna", reminder: 999_999),
            makeTask("done", owner: "anna", status: .done, reminder: 2_000_000),
            makeTask("gone", owner: "anna", reminder: 2_000_000, deleted: true),
            makeTask("none", owner: "anna"),
        ]
        let plan = ReminderPlanner.plan(tasks: tasks, userId: "anna", now: now)
        #expect(plan == [
            ReminderRequest(id: "soon", fireAt: ms(2_000_000), title: "Zadanie soon"),
            ReminderRequest(id: "later", fireAt: ms(3_000_000), title: "Zadanie later"),
        ])
    }

    @Test func planKeepsOnlySoonestSixtyFour() {
        let tasks = (0..<70).map { makeTask("t\($0)", reminder: 2_000_000 + Int64(70 - $0) * 1000) }
        let plan = ReminderPlanner.plan(tasks: tasks, userId: "anna", now: now)
        #expect(plan.count == ReminderPlanner.maxPending)
        #expect(plan.first?.id == "t69")
        #expect(plan.last?.id == "t6")
    }

    func scheduler(_ center: FakeNotificationCenter) -> ReminderScheduler {
        let now = self.now
        return ReminderScheduler(center: center, userId: "anna", now: { now })
    }

    @Test func schedulesMissingReminder() async {
        let center = FakeNotificationCenter()
        await scheduler(center).reconcile([makeTask("t1", reminder: 2_000_000)])
        #expect(center.scheduled == [ReminderRequest(id: "t1", fireAt: ms(2_000_000), title: "Zadanie t1")])
        #expect(center.cancelled.isEmpty)
    }

    @Test func unchangedReminderIsLeftAlone() async {
        let existing = ReminderRequest(id: "t1", fireAt: ms(2_000_000), title: "Zadanie t1")
        let center = FakeNotificationCenter(pending: [existing])
        await scheduler(center).reconcile([makeTask("t1", reminder: 2_000_000), makeTask("x", reminder: 2_500_000)])
        #expect(center.scheduled.map(\.id) == ["x"])  // kontrola: scheduler w ogóle działa
        #expect(center.cancelled.isEmpty)
    }

    @Test func changedReminderTimeIsRescheduledUnderSameID() async {
        let center = FakeNotificationCenter(pending: [ReminderRequest(id: "t1", fireAt: ms(2_000_000), title: "Zadanie t1")])
        await scheduler(center).reconcile([makeTask("t1", reminder: 2_500_000)])
        #expect(center.scheduled == [ReminderRequest(id: "t1", fireAt: ms(2_500_000), title: "Zadanie t1")])
        #expect(center.cancelled.isEmpty)
    }

    @Test func planUsesWholeMillisecondsLikeTheStoredNotification() {
        var task = makeTask("t1")
        task.reminderAt = ms(2_000_000).addingTimeInterval(0.0004)  // DatePicker daje ułamki ms
        let plan = ReminderPlanner.plan(tasks: [task], userId: "anna", now: now)
        #expect(plan == [ReminderRequest(id: "t1", fireAt: ms(2_000_000), title: "Zadanie t1")])
    }

    @Test func reminderWithSubMillisecondTimeIsNotRescheduledEveryTime() async {
        let center = FakeNotificationCenter(pending: [ReminderRequest(id: "t1", fireAt: ms(2_000_000), title: "Zadanie t1")])
        var task = makeTask("t1")
        task.reminderAt = ms(2_000_000).addingTimeInterval(0.0004)
        await scheduler(center).reconcile([task, makeTask("x", reminder: 2_500_000)])
        #expect(center.scheduled.map(\.id) == ["x"])  // kontrola: nowe przypomnienie nadal jest planowane
        #expect(center.cancelled.isEmpty)
    }

    @Test func completedDeletedOrRemovedReminderIsCancelled() async {
        let pending = ["done", "gone", "cleared", "missing"].map {
            ReminderRequest(id: $0, fireAt: ms(2_000_000), title: "Zadanie \($0)")
        }
        let center = FakeNotificationCenter(pending: pending)
        await scheduler(center).reconcile([
            makeTask("done", status: .done, reminder: 2_000_000),
            makeTask("gone", reminder: 2_000_000, deleted: true),
            makeTask("cleared"),
        ])
        #expect(Set(center.cancelled) == ["done", "gone", "cleared", "missing"])
        #expect(center.scheduled.isEmpty)
    }
}
