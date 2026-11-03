import SwiftUI
import TodoCore

@main
struct FamilyTodoApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.identity == nil {
                    SetupView(model: model)
                } else {
                    TaskListView(model: model)
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                model.setActive(phase == .active)
            }
        }
    }
}
