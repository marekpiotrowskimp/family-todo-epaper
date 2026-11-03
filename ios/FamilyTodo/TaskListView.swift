import SwiftUI
import TodoCore

struct TaskListView: View {
    @Bindable var model: AppModel
    @State private var editing: TodoTask?
    @State private var isAdding = false

    private var active: [TodoTask] { model.tasks.filter { $0.status == .active } }
    private var done: [TodoTask] { model.tasks.filter { $0.status == .done } }

    var body: some View {
        NavigationStack {
            List {
                if model.tasks.isEmpty {
                    ContentUnavailableView("Brak zadań", systemImage: "checklist", description: Text("Dodaj pierwsze zadanie przyciskiem +."))
                        .foregroundStyle(Theme.inkSecondary)
                        .listRowBackground(Color.clear)
                }
                if !active.isEmpty {
                    Section { ForEach(active, id: \.id, content: row) } header: { SectionHeader("Do zrobienia") }
                        .surfaceRow()
                }
                if !done.isEmpty {
                    Section { ForEach(done, id: \.id, content: row) } header: { SectionHeader("Zrobione") }
                        .surfaceRow()
                }
                if let message = model.message {
                    Section { Text(message).font(.footnote).foregroundStyle(Theme.inkSecondary) }
                        .surfaceRow()
                }
            }
            .paperScreen()
            .navigationTitle("Zadania")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.isBusy {
                        ProgressView()
                    } else {
                        Button {
                            Task { await model.syncNow() }
                        } label: {
                            Label("Synchronizuj", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .badge(model.pendingCount)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: { Label("Dodaj zadanie", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $isAdding) {
                TaskEditorView(task: nil) { title, priority, due, reminder in
                    model.create(title: title, priority: priority, dueAt: due, reminderAt: reminder)
                }
            }
            .sheet(item: $editing) { task in
                TaskEditorView(task: task) { title, priority, due, reminder in
                    model.save(TaskDraft(title: title, priority: priority, dueAt: due, reminderAt: reminder), for: task.id)
                }
            }
        }
    }

    private func row(_ task: TodoTask) -> some View {
        Button { editing = task } label: {
            HStack(spacing: 12) {
                PriorityMark(priority: task.priority)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? Theme.inkSecondary : Theme.ink)
                    HStack(spacing: 8) {
                        if !model.isMine(task) { Text("od innego domownika") }
                        if let due = task.dueAt { Text(due, format: .dateTime.day().month()) }
                        if task.reminderAt != nil { Image(systemName: "bell").accessibilityLabel("Przypomnienie") }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if task.status == .active {
                Button("Zrobione") { model.complete(task) }.tint(Theme.actionComplete)
            } else {
                Button("Przywróć") { model.reopen(task) }.tint(Theme.actionRestore)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Usuń", role: .destructive) { model.delete(task) }.tint(Theme.actionDelete)
        }
    }
}

extension TodoTask: @retroactive Identifiable {}
