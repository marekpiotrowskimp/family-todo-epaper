import Foundation
import Testing
@testable import TodoCore

@Suite struct AutoSyncPolicyTests {
    let t0 = ms(1_793_430_000_000)

    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func firstSightingSyncsImmediately() {
        #expect(AutoSyncPolicy().fireDate(deviceSeenAt: t0, lastLocalChange: nil) == t0)
    }

    @Test func withoutLocalChangesSyncsAtMostOncePerMinute() {
        var policy = AutoSyncPolicy()
        policy.recordSuccess(at: t0)
        #expect(policy.fireDate(deviceSeenAt: at(30), lastLocalChange: nil) == nil)
        #expect(policy.fireDate(deviceSeenAt: at(59), lastLocalChange: at(-5)) == nil)  // zmiana sprzed sukcesu
        #expect(policy.fireDate(deviceSeenAt: at(60), lastLocalChange: nil) == at(60))
    }

    @Test func localChangeAfterSuccessSyncsAfterDebounce() {
        var policy = AutoSyncPolicy()
        policy.recordSuccess(at: t0)
        #expect(policy.fireDate(deviceSeenAt: at(11), lastLocalChange: at(10)) == at(12))
        #expect(policy.fireDate(deviceSeenAt: at(20), lastLocalChange: at(10)) == at(20))
    }

    @Test func localChangeBeforeAnySuccessAlsoDebounces() {
        #expect(AutoSyncPolicy().fireDate(deviceSeenAt: at(1), lastLocalChange: at(0)) == at(2))
    }

    @Test func failuresBackOffTenThirtySixtySeconds() {
        var policy = AutoSyncPolicy()
        policy.recordFailure(at: t0)
        #expect(policy.consecutiveFailures == 1)
        #expect(policy.fireDate(deviceSeenAt: at(5), lastLocalChange: nil) == at(10))
        policy.recordFailure(at: at(10))
        #expect(policy.fireDate(deviceSeenAt: at(12), lastLocalChange: at(11)) == at(40))
        policy.recordFailure(at: at(40))
        #expect(policy.fireDate(deviceSeenAt: at(41), lastLocalChange: nil) == at(100))
        policy.recordFailure(at: at(100))
        #expect(policy.fireDate(deviceSeenAt: at(101), lastLocalChange: nil) == at(160))
        #expect(policy.fireDate(deviceSeenAt: at(200), lastLocalChange: nil) == at(200))
    }

    @Test func successResetsBackoff() {
        var policy = AutoSyncPolicy()
        policy.recordFailure(at: t0)
        policy.recordFailure(at: at(10))
        policy.recordSuccess(at: at(50))
        #expect(policy.consecutiveFailures == 0)
        #expect(policy.lastFailure == nil)
        #expect(policy.lastSuccess == at(50))
        #expect(policy.fireDate(deviceSeenAt: at(52), lastLocalChange: at(51)) == at(53))
    }
}
