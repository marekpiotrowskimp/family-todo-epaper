import SwiftUI
import TodoCore

/// Historia wykonanych zadań z datą i godziną wykonania, od najnowszego.
struct HistoryView: View {
    @Bindable var model: AppModel

    var body: some View {
        List {
            if model.history.isEmpty {
                ContentUnavailableView(
                    "Brak wykonanych zadań", systemImage: "clock",
                    description: Text("Zadania oznaczone jako zrobione trafią tutaj."))
                    .foregroundStyle(Theme.inkSecondary)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(model.history, id: \.task.id, content: row)
                } header: {
                    SectionHeader("Wykonane")
                }
                .surfaceRow()
            }
            if let message = model.message {
                Section { Text(message).font(.footnote).foregroundStyle(Theme.inkSecondary) }
                    .surfaceRow()
            }
        }
        .paperScreen()
        .navigationTitle("Historia")
    }

    private func row(_ entry: HistoryEntry) -> some View {
        HStack(spacing: 12) {
            PriorityMark(priority: entry.task.priority)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.task.title)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    Text("Wykonano \(HistoryFormat.completedLabel(entry.completedAt, now: .now, calendar: .current))")
                    if !model.isMine(entry.task) { Text("od innego domownika") }
                }
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .leading) {
            Button("Przywróć") { model.reopen(entry.task) }.tint(Theme.actionRestore)
        }
        .swipeActions(edge: .trailing) {
            Button("Usuń", role: .destructive) { model.delete(entry.task) }.tint(Theme.actionDelete)
        }
    }
}
