import SwiftUI
import TodoCore

struct TaskEditorView: View {
    /// Zwraca `true`, gdy zapis się udał (inaczej formularz zostaje otwarty, a błąd pokazuje lista).
    typealias Save = (_ title: String, _ note: String, _ priority: Priority, _ due: Date?, _ reminder: Date?) -> Bool

    let task: TodoTask?
    let onSave: Save
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    /// Notatka tylko w tym telefonie; nie trafia na wyświetlacz.
    @State private var note: String
    @State private var priority: Priority
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var hasReminder: Bool
    @State private var reminder: Date
    /// Rozwinięty panel daty (kalendarz albo koło godzin) — najwyżej jeden, w treści formularza.
    @State private var panels = EditorPanels()

    init(task: TodoTask?, note: String = "", onSave: @escaping Save) {
        self.task = task
        self.onSave = onSave
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        _title = State(initialValue: task?.title ?? "")
        _note = State(initialValue: note)
        _priority = State(initialValue: task?.priority ?? .normal)
        _hasDue = State(initialValue: task?.dueAt != nil)
        _due = State(initialValue: task?.dueAt ?? nextHour)
        _hasReminder = State(initialValue: task?.reminderAt != nil)
        _reminder = State(initialValue: task?.reminderAt ?? nextHour)
    }

    private var titleBytes: Int { title.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count }
    private var noteBytes: Int { note.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Co trzeba zrobić?", text: $title, axis: .vertical)
                        .foregroundStyle(Theme.ink)
                } footer: {
                    if titleBytes > TaskLimits.maxTitleBytes {
                        Text("Za długi tytuł (\(titleBytes)/\(TaskLimits.maxTitleBytes) bajtów).").foregroundStyle(Theme.danger)
                    }
                }
                .surfaceRow()
                Section {
                    // Dłuższy tekst przewija się wewnątrz pola (maks. 10 widocznych wierszy).
                    TextField("Notatka (opcjonalnie)", text: $note, axis: .vertical)
                        .lineLimit(3...10)
                        .foregroundStyle(Theme.ink)
                } header: {
                    SectionHeader("Notatka")
                } footer: {
                    if noteBytes > TaskLimits.maxNoteBytes {
                        Text("Za długa notatka (\(noteBytes)/\(TaskLimits.maxNoteBytes) bajtów).").foregroundStyle(Theme.danger)
                    } else {
                        Text("Notatka jest widoczna tylko na tym telefonie.").foregroundStyle(Theme.inkSecondary)
                    }
                }
                .surfaceRow()
                Section {
                    Picker(selection: $priority) {
                        Label("Wysoki", systemImage: PriorityStyle.symbolName(for: .high)).tag(Priority.high)
                        Label("Normalny", systemImage: PriorityStyle.symbolName(for: .normal)).tag(Priority.normal)
                        Label("Niski", systemImage: PriorityStyle.symbolName(for: .low)).tag(Priority.low)
                    } label: {
                        Text("Priorytet").foregroundStyle(Theme.ink)
                    }
                }
                .surfaceRow()
                Section {
                    Toggle(isOn: $hasDue) { Text("Termin").foregroundStyle(Theme.ink) }
                    if hasDue {
                        panelRow("Dzień", value: Self.dayText(due), panel: .dueDay)
                        if panels.open == .dueDay { calendar(for: $due, field: .due) }
                    }
                }
                .surfaceRow()
                Section {
                    Toggle(isOn: $hasReminder) { Text("Przypomnienie").foregroundStyle(Theme.ink) }
                    if hasReminder {
                        panelRow("Dzień", value: Self.dayText(reminder), panel: .reminderDay)
                        if panels.open == .reminderDay { calendar(for: $reminder, field: .reminder) }
                        panelRow("Godzina", value: reminder.formatted(date: .omitted, time: .shortened), panel: .reminderTime)
                        if panels.open == .reminderTime {
                            DatePicker("Godzina przypomnienia", selection: reminderTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                        }
                    }
                } footer: {
                    Text("Przypomnienie przychodzi na ten telefon, także bez połączenia z wyświetlaczem.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
            }
            .paperScreen()
            .onChange(of: hasDue) { _, on in
                withAnimation { on ? panels.enabled(.due) : panels.disabled(.due) }
            }
            .onChange(of: hasReminder) { _, on in
                withAnimation { on ? panels.enabled(.reminder) : panels.disabled(.reminder) }
            }
            .navigationTitle(task == nil ? Text("Nowe zadanie") : Text("Edycja"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        if onSave(title, note, priority, hasDue ? due : nil, hasReminder ? reminder : nil) { dismiss() }
                    }
                    .disabled(titleBytes == 0 || titleBytes > TaskLimits.maxTitleBytes || noteBytes > TaskLimits.maxNoteBytes)
                }
            }
        }
    }

    // MARK: - Panele dat

    private static func dayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// Wiersz z aktualną wartością; dotknięcie rozwija lub zwija jego panel (i zwija inny).
    private func panelRow(_ title: LocalizedStringKey, value: String, panel: EditorPanel) -> some View {
        Button {
            withAnimation { panels.tap(panel) }
        } label: {
            HStack {
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                Text(value)
                    .foregroundStyle(panels.open == panel ? Theme.ink : Theme.inkSecondary)
                    .fontWeight(panels.open == panel ? .semibold : .regular)
            }
        }
        .accessibilityValue(value)
        .accessibilityHint(panels.open == panel ? Text("Zwija wybór") : Text("Rozwija wybór"))
    }

    /// Kalendarz w treści formularza: wybór dnia zostawia godzinę i sam przechodzi dalej.
    private func calendar(for date: Binding<Date>, field: DateField) -> some View {
        DatePicker(
            "Dzień",
            selection: Binding(
                get: { date.wrappedValue },
                set: { day in
                    date.wrappedValue = DayTime.settingDay(of: day, on: date.wrappedValue, calendar: .current)
                    withAnimation { panels.pickedDay(field) }
                }),
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { reminder },
            set: { reminder = DayTime.settingTime(of: $0, on: reminder, calendar: .current) })
    }
}
