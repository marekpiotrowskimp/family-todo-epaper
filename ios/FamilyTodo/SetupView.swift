import SwiftUI
import TodoCore

/// Pierwsze uruchomienie: imię pokazywane na wyświetlaczu i klucz rodziny (można dodać później).
struct SetupView: View {
    let model: AppModel
    @State private var name: String
    @State private var keyText = ""

    init(model: AppModel) {
        self.model = model
        _name = State(initialValue: model.isDemo ? "Anna" : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Imię", text: $name)
                        .foregroundStyle(Theme.ink)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                } footer: {
                    Text("To imię pojawi się na wyświetlaczu obok Twoich zadań.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
                Section {
                    if model.familyKey != nil {
                        Label("Klucz rodziny zapisany", systemImage: "key.fill").foregroundStyle(Theme.ink)
                    } else {
                        FamilyKeyField(text: $keyText)
                    }
                } header: {
                    SectionHeader("Klucz rodziny")
                } footer: {
                    Text("Zeskanuj aparatem iPhone'a kod QR klucza (z komputera, na którym zbudowano wyświetlacz, albo z ustawień aplikacji domownika) lub wklej klucz. Bez klucza aplikacja działa jako lista na tym telefonie.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
                Section {
                    Button("Dalej") { model.setUp(displayName: name, keyText: keyText) }
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

/// Pole na klucz rodziny z przyciskiem wklejania.
struct FamilyKeyField: View {
    @Binding var text: String

    var body: some View {
        HStack {
            TextField("Klucz (64 znaki) lub link", text: $text)
                .foregroundStyle(Theme.ink)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            PasteButton(payloadType: String.self) { strings in
                if let first = strings.first { text = first }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
        }
    }
}
