import Foundation

/// Osobna edycja dnia i godziny jednej daty (formularz zadania).
public enum DayTime {
    /// Dzień z `day`, godzina i minuta z `value` (sekundy z `value`).
    public static func settingDay(of day: Date, on value: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        let time = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: value)
        parts.hour = time.hour
        parts.minute = time.minute
        parts.second = time.second
        parts.nanosecond = time.nanosecond
        return calendar.date(from: parts) ?? value
    }

    /// Dzień z `value`, godzina i minuta z `time`, sekundy = 0.
    public static func settingTime(of time: Date, on value: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: value)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        parts.hour = clock.hour
        parts.minute = clock.minute
        parts.second = 0
        return calendar.date(from: parts) ?? value
    }
}

public enum DateField: Sendable {
    case due
    case reminder
}

/// Rozwijany w formularzu panel wyboru (kalendarz albo koło godzin), zawsze w treści formularza.
public enum EditorPanel: Equatable, Sendable {
    case dueDay
    case reminderDay
    case reminderTime
}

/// Który panel daty jest rozwinięty. Najwyżej jeden naraz, nic nie trzeba zamykać ręcznie.
public struct EditorPanels: Equatable, Sendable {
    public private(set) var open: EditorPanel?

    public init(open: EditorPanel? = nil) {
        self.open = open
    }

    /// Dotknięcie wiersza: rozwija jego panel (zwijając inny) albo zwija, gdy był rozwinięty.
    public mutating func tap(_ panel: EditorPanel) {
        open = open == panel ? nil : panel
    }

    /// Włączenie przełącznika „Termin”/„Przypomnienie”: od razu rozwija wybór dnia.
    public mutating func enabled(_ field: DateField) {
        open = Self.dayPanel(of: field)
    }

    /// Wyłączenie przełącznika: zwija panele tego pola.
    public mutating func disabled(_ field: DateField) {
        guard let open, Self.field(of: open) == field else { return }
        self.open = nil
    }

    /// Wybrano dzień w kalendarzu: termin się zwija, przypomnienie przechodzi do godziny.
    public mutating func pickedDay(_ field: DateField) {
        guard open == Self.dayPanel(of: field) else { return }
        open = field == .reminder ? .reminderTime : nil
    }

    private static func dayPanel(of field: DateField) -> EditorPanel {
        switch field {
        case .due: .dueDay
        case .reminder: .reminderDay
        }
    }

    private static func field(of panel: EditorPanel) -> DateField {
        switch panel {
        case .dueDay: .due
        case .reminderDay, .reminderTime: .reminder
        }
    }
}
