import Foundation
import Testing
@testable import TodoCore

@Suite struct LWWTests {
    @Test func newerUpdatedAtWins() {
        let older = makeTask("t1", updated: 1000)
        let newer = makeTask("t1", updated: 2000)
        #expect(LWW.wins(newer, over: older))
        #expect(!LWW.wins(older, over: newer))
    }

    @Test func tieOnUpdatedAtIsBrokenByGreaterUpdatedBy() {
        let byAnna = makeTask("t1", updated: 5000, by: "anna")
        let byBartek = makeTask("t1", updated: 5000, by: "bartek")
        #expect(LWW.wins(byBartek, over: byAnna))
        #expect(!LWW.wins(byAnna, over: byBartek))
    }

    @Test func sameVersionDoesNotWin() {
        let v = makeTask("t1", updated: 5000)
        #expect(LWW.wins(makeTask("t1", updated: 5001), over: v))  // kontrola
        #expect(!LWW.wins(v, over: v))
    }
}

@Suite struct DisplayOrderTests {
    /// Te same przypadki co test_display/test_global_order… w firmware.
    @Test func ordersByPriorityThenDueThenCreatedThenID() {
        let tasks = [
            makeTask("l_due", priority: .low, due: 500),
            makeTask("n_nodue_new", priority: .normal, created: 200),
            makeTask("h_nodue", priority: .high),
            makeTask("n_nodue_old_b", priority: .normal, created: 100),
            makeTask("h_due2", priority: .high, due: 2000),
            makeTask("n_due1", priority: .normal, due: 1000),
            makeTask("n_nodue_old", priority: .normal, created: 100),
            makeTask("h_due1", priority: .high, due: 1000),
        ]
        let sorted = tasks.sorted(by: DisplayOrder.areInIncreasingOrder).map(\.id)
        #expect(sorted == [
            "h_due1", "h_due2", "h_nodue", "n_due1", "n_nodue_old", "n_nodue_old_b", "n_nodue_new", "l_due",
        ])
    }
}
