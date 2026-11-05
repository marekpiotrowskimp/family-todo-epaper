import Foundation

/// Pozycja historii: ukończone zadanie i moment, w którym zostało wykonane.
public struct HistoryEntry: Equatable, Sendable {
    public let task: TodoTask
    public let completedAt: Date

    public init(task: TodoTask, completedAt: Date) {
        self.task = task
        self.completedAt = completedAt
    }
}

/// Tekst „kiedy wykonano” w historii.
public enum HistoryFormat {
    /// "dziś, 14:32", "wczoraj, 9:05", "03.11, 14:32" (ten sam rok), "03.11.2025, 14:32" (inny rok).
    public static func completedLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let clock = String(format: "%d:%02d", time.hour ?? 0, time.minute ?? 0)
        if calendar.isDate(date, inSameDayAs: now) { return "dziś, \(clock)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "wczoraj, \(clock)"
        }
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let dayMonth = String(format: "%02d.%02d", day.day ?? 0, day.month ?? 0)
        if day.year == calendar.component(.year, from: now) { return "\(dayMonth), \(clock)" }
        return "\(dayMonth).\(day.year ?? 0), \(clock)"
    }
}
