import Foundation
import TodoCore
import UserNotifications

/// `NotificationScheduling` na `UNUserNotificationCenter`. Dokładny czas przypomnienia trzymamy
/// w `userInfo`, żeby `ReminderScheduler` mógł porównać go bez zaokrągleń kalendarza.
@MainActor
final class UserNotificationScheduler: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()
    private static let fireAtKey = "fireAtMs"

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func pendingReminders() async -> [ReminderRequest] {
        await center.pendingNotificationRequests().compactMap { request in
            guard let ms = request.content.userInfo[Self.fireAtKey] as? Int64 else { return nil }
            return ReminderRequest(
                id: request.identifier,
                fireAt: Date(timeIntervalSince1970: Double(ms) / 1000),
                title: request.content.body)
        }
    }

    func schedule(_ reminder: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Przypomnienie")
        content.body = reminder.title
        content.sound = .default
        content.userInfo = [Self.fireAtKey: Int64((reminder.fireAt.timeIntervalSince1970 * 1000).rounded())]
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: reminder.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
    }

    func cancel(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}
