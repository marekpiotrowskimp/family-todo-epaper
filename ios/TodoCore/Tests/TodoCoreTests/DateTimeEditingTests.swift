import Foundation
import Testing
@testable import TodoCore

/// Formularz zadania: dzień i godzinę wybiera się w osobnych, rozwijanych w treści panelach,
/// więc żeby zmienić godzinę nie trzeba zamykać kalendarza.
@Suite struct DateTimeEditingTests {
    static let warsaw: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }()

    static func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        warsaw.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    // MARK: - Dzień i godzina osobno

    @Test func pickingDayKeepsChosenTime() {
        let value = Self.at(2026, 11, 5, 14, 30)
        let day = Self.at(2026, 11, 20, 0, 0)
        #expect(DayTime.settingDay(of: day, on: value, calendar: Self.warsaw) == Self.at(2026, 11, 20, 14, 30))
    }

    @Test func pickingDayIgnoresTimeOfDayCarriedByCalendarValue() {
        // Kalendarz oddaje datę z dowolną godziną; liczy się tylko dzień.
        let value = Self.at(2026, 11, 5, 7, 15)
        let day = Self.at(2026, 12, 24, 22, 45)
        #expect(DayTime.settingDay(of: day, on: value, calendar: Self.warsaw) == Self.at(2026, 12, 24, 7, 15))
    }

    @Test func pickingTimeKeepsChosenDayAndClearsSeconds() {
        let value = Self.at(2026, 11, 20, 14, 30, 41)
        let time = Self.at(2026, 1, 1, 9, 5, 17)
        #expect(DayTime.settingTime(of: time, on: value, calendar: Self.warsaw) == Self.at(2026, 11, 20, 9, 5, 0))
    }

    @Test func pickingDayAcrossDaylightSavingChangeKeepsWallClockTime() {
        // 2026-03-29 Polska przechodzi na czas letni; 14:30 ma zostać 14:30, a nie 15:30.
        let winter = Self.at(2026, 3, 28, 14, 30)
        let summerDay = Self.at(2026, 3, 30, 0, 0)
        let result = DayTime.settingDay(of: summerDay, on: winter, calendar: Self.warsaw)
        #expect(result == Self.at(2026, 3, 30, 14, 30))
        #expect(Self.warsaw.component(.hour, from: result) == 14)
    }

    // MARK: - Rozwijane panele

    @Test func freshFormHasNoPanelOpen() {
        #expect(EditorPanels().open == nil)
    }

    @Test func enablingReminderOpensItsCalendarAndPickingDayMovesToTime() {
        var panels = EditorPanels()
        panels.enabled(.reminder)
        #expect(panels.open == .reminderDay)
        panels.pickedDay(.reminder)
        #expect(panels.open == .reminderTime)
    }

    @Test func enablingDueOpensItsCalendarAndPickingDayClosesIt() {
        var panels = EditorPanels()
        panels.enabled(.due)
        #expect(panels.open == .dueDay)
        panels.pickedDay(.due)
        #expect(panels.open == nil)
    }

    @Test func tappingTimeRowWhileCalendarIsOpenSwitchesDirectlyToTime() {
        var panels = EditorPanels(open: .reminderDay)
        panels.tap(.reminderTime)
        #expect(panels.open == .reminderTime)
    }

    @Test func tappingAnotherFieldClosesPreviousPanel() {
        var panels = EditorPanels(open: .dueDay)
        panels.tap(.reminderDay)
        #expect(panels.open == .reminderDay)
        panels.tap(.dueDay)
        #expect(panels.open == .dueDay)
    }

    @Test func tappingOpenRowCollapsesIt() {
        var panels = EditorPanels(open: .reminderTime)
        panels.tap(.reminderTime)
        #expect(panels.open == nil)
    }

    @Test(arguments: [EditorPanel.reminderDay, .reminderTime])
    func disablingReminderClosesItsPanels(open: EditorPanel) {
        var panels = EditorPanels(open: open)
        panels.disabled(.reminder)
        #expect(panels.open == nil)
    }

    @Test func disablingOtherFieldLeavesOpenPanel() {
        var panels = EditorPanels(open: .reminderTime)
        panels.disabled(.due)
        #expect(panels.open == .reminderTime)
        panels = EditorPanels(open: .dueDay)
        panels.disabled(.reminder)
        #expect(panels.open == .dueDay)
    }

    @Test func pickingDayOfFieldWhoseCalendarIsClosedDoesNotOpenAnything() {
        // Zmiana daty przyszła spoza kalendarza (np. inicjalizacja), panel jest zwinięty.
        var panels = EditorPanels()
        panels.pickedDay(.reminder)
        #expect(panels.open == nil)
        panels = EditorPanels(open: .dueDay)
        panels.pickedDay(.reminder)
        #expect(panels.open == .dueDay)
    }
}
