import SwiftUI
import TodoCore

struct TaskEditorView: View {
    /// Zwraca `true`, gdy zapis się udał (inaczej formularz zostaje otwarty, a błąd pokazuje lista).
    typealias Save = (_ title: String, _ priority: Priority, _ due: Date?, _ reminder: Date?) -> Bool

    let task: TodoTask?
    let onSave: Save
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var priority: Priority
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var hasReminder: Bool
    @State private var reminder: Date

    init(task: TodoTask?, onSave: @escaping Save) {
        self.task = task
        self.onSave = onSave
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        _title = State(initialValue: task?.title ?? "")
        _priority = State(initialValue: task?.priority ?? .normal)
        _hasDue = State(initialValue: task?.dueAt != nil)
        _due = State(initialValue: task?.dueAt ?? nextHour)
        _hasReminder = State(initialValue: task?.reminderAt != nil)
        _reminder = State(initialValue: task?.reminderAt ?? nextHour)
    }

    private var titleBytes: Int { title.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count }

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
                        DatePicker(selection: $due, displayedComponents: .date) { Text("Data").foregroundStyle(Theme.ink) }
                    }
                }
                .surfaceRow()
                Section {
                    Toggle(isOn: $hasReminder) { Text("Przypomnienie").foregroundStyle(Theme.ink) }
                    if hasReminder {
                        DatePicker(selection: $reminder) { Text("Kiedy").foregroundStyle(Theme.ink) }
                    }
                } footer: {
                    Text("Przypomnienie przychodzi na ten telefon, także bez połączenia z wyświetlaczem.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
            }
            .paperScreen()
            .navigationTitle(task == nil ? "Nowe zadanie" : "Edycja")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Anuluj") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        if onSave(title, priority, hasDue ? due : nil, hasReminder ? reminder : nil) { dismiss() }
                    }
                    .disabled(titleBytes == 0 || titleBytes > TaskLimits.maxTitleBytes)
                }
            }
        }
    }
}
