import SwiftUI
import TodoCore

/// Kolory aplikacji z Assets.xcassets (wartości: `AppPalette` w TodoCore, zgodność pilnują testy).
/// Akcent (`AccentColor`) jest globalny, więc przyciski i przełączniki nie potrzebują `.tint`.
enum Theme {
    static let paper = Color(AppPalette.paper.assetName)
    static let surface = Color(AppPalette.surface.assetName)
    static let ink = Color(AppPalette.ink.assetName)
    static let inkSecondary = Color(AppPalette.inkSecondary.assetName)
    static let danger = Color(AppPalette.danger.assetName)
    static let actionComplete = Color(AppPalette.actionComplete.assetName)
    static let actionRestore = Color(AppPalette.actionRestore.assetName)
    static let actionDelete = Color(AppPalette.actionDelete.assetName)
}

extension View {
    /// Ekran z listą lub formularzem na tle papieru: systemowe tło ukryte, pasek nawigacji w tym samym kolorze.
    /// Kolor tekstu ustawiają same wiersze (`Theme.ink`), żeby przyciski zachowały kolor akcentu.
    func paperScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.paper)
            .toolbarBackground(Theme.paper, for: .navigationBar)
    }

    /// Wiersz lub sekcja listy na tle `Surface`.
    func surfaceRow() -> some View {
        listRowBackground(Theme.surface)
    }
}

/// Nagłówek sekcji listy w kolorze tekstu pomocniczego palety.
struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title).foregroundStyle(Theme.inkSecondary)
    }
}

/// Ikona priorytetu: te same znaczenia co na e-papierze (pełna flaga, flaga w obrysie, kreska).
struct PriorityMark: View {
    let priority: Priority

    var body: some View {
        Image(systemName: PriorityStyle.symbolName(for: priority))
            .font(.subheadline)
            .frame(width: 22)
            .foregroundStyle(Theme.ink)
            .accessibilityLabel(Text(LocalizedStringKey(PriorityStyle.accessibilityLabel(for: priority))))
    }
}
