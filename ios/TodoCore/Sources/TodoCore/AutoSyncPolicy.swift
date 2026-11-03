import Foundation

/// Kiedy aplikacja ma sama zsynchronizować się z wyświetlaczem, który właśnie zobaczyła w zasięgu BLE.
/// Ręczna synchronizacja omija tę politykę.
public struct AutoSyncPolicy: Equatable, Sendable {
    /// Odczekanie po ostatniej lokalnej zmianie (seria edycji = jedna synchronizacja).
    public static let debounce: TimeInterval = 2
    /// Bez lokalnych zmian: pobieranie cudzych zmian najwyżej raz na minutę.
    public static let refreshInterval: TimeInterval = 60
    /// Odstęp po kolejnych nieudanych próbach (ostatnia wartość powtarza się).
    public static let backoff: [TimeInterval] = [10, 30, 60]

    public private(set) var lastSuccess: Date?
    public private(set) var lastFailure: Date?
    public private(set) var consecutiveFailures = 0

    public init() {}

    /// Kiedy uruchomić synchronizację po zobaczeniu urządzenia w chwili `now`; `nil` = nie teraz.
    /// - Lokalna zmiana nowsza niż ostatni sukces (albo brak sukcesu): `max(now, lastLocalChange + debounce)`.
    /// - Bez takich zmian: `now`, jeśli nie było sukcesu albo minęło `refreshInterval`; inaczej `nil`.
    /// - Po porażkach wynik nie jest wcześniejszy niż `lastFailure + backoff[min(n - 1, 2)]`.
    public func fireDate(deviceSeenAt now: Date, lastLocalChange: Date?) -> Date? {
        var fire: Date
        if let change = lastLocalChange, lastSuccess.map({ change > $0 }) ?? true {
            fire = max(now, change.addingTimeInterval(Self.debounce))
        } else if let lastSuccess, now.timeIntervalSince(lastSuccess) < Self.refreshInterval {
            return nil
        } else {
            fire = now
        }
        if consecutiveFailures > 0, let lastFailure {
            let wait = Self.backoff[min(consecutiveFailures, Self.backoff.count) - 1]
            fire = max(fire, lastFailure.addingTimeInterval(wait))
        }
        return fire
    }

    public mutating func recordSuccess(at date: Date) {
        lastSuccess = date
        lastFailure = nil
        consecutiveFailures = 0
    }

    public mutating func recordFailure(at date: Date) {
        lastFailure = date
        consecutiveFailures += 1
    }
}
