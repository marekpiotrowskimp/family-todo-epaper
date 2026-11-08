import CoreImage.CIFilterBuiltins
import SwiftUI
import TodoCore

/// Ustawienia: imię, klucz rodziny (kod QR dla domowników, zmiana, usunięcie).
struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsCode: Bool
    @State private var isReplacing = false
    @State private var keyText = ""

    init(model: AppModel, showsCode: Bool = false) {
        self.model = model
        _showsCode = State(initialValue: showsCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Imię na wyświetlaczu", value: model.identity?.displayName ?? "")
                        .foregroundStyle(Theme.ink)
                }
                .surfaceRow()
                keySection
                Section {
                    Link(destination: URL(string: "https://github.com/marekpiotrowskimp/family-todo-epaper")!) {
                        Label("Jak zbudować wyświetlacz", systemImage: "hammer")
                    }
                } footer: {
                    Text("Wyświetlacz e-papierowy (ESP32-S3) budujesz sam według otwartej instrukcji. Aplikacja nie wysyła danych do internetu.")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .surfaceRow()
                if let message = model.message {
                    Section { Text(message).font(.footnote).foregroundStyle(Theme.inkSecondary) }
                        .surfaceRow()
                }
            }
            .paperScreen()
            .navigationTitle("Ustawienia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Gotowe") { dismiss() } }
            }
        }
    }

    @ViewBuilder private var keySection: some View {
        Section {
            if let key = model.familyKey, !isReplacing {
                Label("Klucz rodziny zapisany", systemImage: "key.fill").foregroundStyle(Theme.ink)
                Toggle(isOn: $showsCode.animation()) { Text("Pokaż kod QR dla domownika").foregroundStyle(Theme.ink) }
                if showsCode {
                    QRCodeImage(text: FamilyKeyCode.url(for: key).absoluteString)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                Button("Zmień klucz") { withAnimation { isReplacing = true } }
                Button("Usuń klucz", role: .destructive) { model.removeFamilyKey() }
            } else {
                FamilyKeyField(text: $keyText)
                Button("Zapisz klucz") {
                    if model.setFamilyKey(keyText) {
                        keyText = ""
                        withAnimation { isReplacing = false }
                    }
                }
                .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if isReplacing { Button("Anuluj") { withAnimation { isReplacing = false } } }
            }
        } header: {
            SectionHeader("Klucz rodziny")
        } footer: {
            Text(model.familyKey == nil
                 ? "Bez klucza zadania zostają na tym telefonie. Klucz utworzysz poleceniem tools/make-family-key.sh przy budowie wyświetlacza."
                 : "Domownik skanuje ten kod aparatem iPhone'a i otwiera link w aplikacji. Kto ma klucz, może zmieniać zadania rodziny — pokazuj go tylko domownikom.")
                .foregroundStyle(Theme.inkSecondary)
        }
        .surfaceRow()
    }
}

/// Kod QR z tekstu (CoreImage), skalowany bez wygładzania.
struct QRCodeImage: View {
    let text: String

    var body: some View {
        if let image = Self.render(text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(Text("Kod QR klucza rodziny"))
        }
    }

    private static func render(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
