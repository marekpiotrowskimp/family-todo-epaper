#if DEBUG
import Foundation
import TodoCore

/// Tryb demonstracyjny do zrzutów ekranu App Store (tylko w buildzie Debug):
/// `-demoScreen list|editor|history|settings|setup` w argumentach uruchomienia.
/// Dane są w pamięci, w języku urządzenia; nic nie trafia do Keychain ani do pliku zadań.
enum DemoScreen: String {
    case list, editor, history, settings, setup

    static var current: DemoScreen? {
        UserDefaults.standard.string(forKey: "demoScreen").flatMap(DemoScreen.init(rawValue:))
    }
}

enum DemoData {
    static let key = Data((0..<32).map { UInt8(($0 * 37 + 11) & 0xff) })

    @MainActor static func model() -> AppModel {
        let english = Locale.preferredLanguages.first?.hasPrefix("en") ?? false
        let storage = InMemoryTaskStorage()
        var clock = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now)!
        let now: () -> Date = { clock }
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
            return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
        }
        let text = english ? englishTitles : polishTitles

        // Zadania domowników (inne userId), potem własne — wszystkie w jednym magazynie.
        let others = try! TaskRepository(userId: "demo-bartek", storage: storage, now: now)
        _ = try! others.create(title: text[0], priority: .high, dueAt: day(0, 18), reminderAt: nil)
        _ = try! others.create(title: text[1], priority: .normal, dueAt: day(2, 12), reminderAt: nil)
        let doneOther = try! others.create(title: text[2], priority: .normal, dueAt: nil, reminderAt: nil)
        clock = day(-1, 19, 40); try! others.complete(id: doneOther.id)

        let mine = try! TaskRepository(userId: "demo-anna", storage: storage, now: now)
        clock = day(0, 8)
        let notes = english ? englishNotes : polishNotes
        _ = try! mine.create(
            title: text[3], note: notes[0], priority: .high, dueAt: day(1, 9), reminderAt: day(1, 7, 30))
        _ = try! mine.create(
            title: text[4], note: notes[1], priority: .normal, dueAt: day(0, 17), reminderAt: day(0, 16, 30))
        _ = try! mine.create(title: text[5], priority: .normal, dueAt: nil, reminderAt: nil)
        _ = try! mine.create(title: text[6], priority: .low, dueAt: day(5, 12), reminderAt: nil)
        _ = try! mine.create(title: text[7], priority: .low, dueAt: nil, reminderAt: nil)
        let done1 = try! mine.create(title: text[8], priority: .high, dueAt: nil, reminderAt: nil)
        let done2 = try! mine.create(title: text[9], priority: .normal, dueAt: nil, reminderAt: nil)
        let done3 = try! mine.create(title: text[10], priority: .low, dueAt: nil, reminderAt: nil)
        clock = day(0, 7, 15); try! mine.complete(id: done1.id)
        clock = day(-1, 21, 5); try! mine.complete(id: done2.id)
        clock = day(-3, 10, 30); try! mine.complete(id: done3.id)
        clock = .now

        let repository = try! TaskRepository(userId: "demo-anna", storage: storage)
        let screen = DemoScreen.current
        return AppModel(
            demoIdentity: Identity(userId: "demo-anna", displayName: "Anna"),
            familyKey: screen == .setup ? nil : key,
            repository: repository,
            needsSetup: screen == .setup)
    }

    static let polishTitles = [
        "Wynieść śmieci", "Odebrać paczkę", "Podlać kwiaty",
        "Zawieźć Zosię na basen", "Kupić mleko i chleb", "Zadzwonić do babci",
        "Umyć okna", "Wymienić żarówkę w przedpokoju",
        "Zapłacić rachunek za prąd", "Pranie", "Odkurzyć samochód",
    ]
    /// Notatki (tylko w telefonie): do zadania w edytorze i do jednego zadania na liście.
    static let polishNotes = [
        "Strój, czepek, ręcznik i klapki.\nTrening 8:00–9:00, odbiór przy wejściu B.",
        "Mleko 2%, chleb razowy.",
    ]
    static let englishNotes = [
        "Swimsuit, cap, towel and flip-flops.\nPractice 8–9 am, pick-up at entrance B.",
        "2% milk, wholegrain bread.",
    ]
    static let englishTitles = [
        "Take out the trash", "Pick up the parcel", "Water the plants",
        "Drive Zoe to swimming", "Buy milk and bread", "Call grandma",
        "Wash the windows", "Replace the hallway bulb",
        "Pay the electricity bill", "Laundry", "Vacuum the car",
    ]
}
#endif
