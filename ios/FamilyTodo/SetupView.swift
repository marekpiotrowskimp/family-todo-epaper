import SwiftUI

/// Pierwsze uruchomienie: imię pokazywane na wyświetlaczu przy zadaniach tej osoby.
struct SetupView: View {
    let model: AppModel
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Imię", text: $name)
                        .foregroundStyle(Theme.ink)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .onSubmit { model.setUp(displayName: name) }
                } footer: {
                    Text("To imię pojawi się na wyświetlaczu obok Twoich zadań.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
                Section {
                    Button("Dalej") { model.setUp(displayName: name) }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let message = model.message {
                        Text(message).foregroundStyle(Theme.danger)
                    }
                }
                .surfaceRow()
            }
            .paperScreen()
            .navigationTitle("Witaj")
        }
    }
}
