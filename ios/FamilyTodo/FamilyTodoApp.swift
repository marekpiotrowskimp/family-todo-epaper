import SwiftUI
import TodoCore

@main
struct FamilyTodoApp: App {
    @State private var model = Self.makeModel()
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
            .onOpenURL { model.handle(url: $0) }  // familytodo://key?k=… z kodu QR
        }
    }

    @MainActor private static func makeModel() -> AppModel {
        #if DEBUG
        if DemoScreen.current != nil { return DemoData.model() }
        #endif
        return AppModel()
    }
}
