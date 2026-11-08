import SwiftUI
import TodoCore

struct TaskListView: View {
    @Bindable var model: AppModel
    @State private var editing: TodoTask?
    @State private var isAdding = false
    @State private var showsHistory = false
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            List {
                if model.tasks.isEmpty {
                    ContentUnavailableView("Brak zadań", systemImage: "checklist", description: Text("Dodaj pierwsze zadanie przyciskiem +."))
                        .foregroundStyle(Theme.inkSecondary)
                        .listRowBackground(Color.clear)
                }
                if !model.tasks.isEmpty {
                    Section { ForEach(model.tasks, id: \.id, content: row) } header: { SectionHeader("Do zrobienia") }
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
                    Button { showsSettings = true } label: { Label("Ustawienia", systemImage: "gearshape") }
                }
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
                    Button { showsHistory = true } label: {
                        Label("Historia", systemImage: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: { Label("Dodaj zadanie", systemImage: "plus") }
                }
            }
            .navigationDestination(isPresented: $showsHistory) { HistoryView(model: model) }
            .sheet(isPresented: $showsSettings) { SettingsView(model: model, showsCode: model.isDemo) }
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
        .onAppear(perform: openDemoScreen)
    }

    /// Zrzuty ekranu: od razu otwiera ekran wskazany argumentem `-demoScreen`.
    private func openDemoScreen() {
        #if DEBUG
        guard model.isDemo else { return }
        switch DemoScreen.current {
        case .editor: editing = model.tasks.first { $0.reminderAt != nil && model.isMine($0) }
        case .history: showsHistory = true
        case .settings: showsSettings = true
        default: break
        }
        #endif
    }

    private func row(_ task: TodoTask) -> some View {
        Button { editing = task } label: {
            HStack(spacing: 12) {
                PriorityMark(priority: task.priority)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .foregroundStyle(Theme.ink)
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
            Button("Zrobione") { model.complete(task) }.tint(Theme.actionComplete)
        }
        .swipeActions(edge: .trailing) {
            Button("Usuń", role: .destructive) { model.delete(task) }.tint(Theme.actionDelete)
        }
    }
}

extension TodoTask: @retroactive Identifiable {}
