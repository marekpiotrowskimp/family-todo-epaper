import Foundation

/// Kolor sRGB 8-bit.
public struct RGB: Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `hex` w postaci 0xRRGGBB.
    public init(hex: UInt32) {
        self.init(red: UInt8(hex >> 16 & 0xFF), green: UInt8(hex >> 8 & 0xFF), blue: UInt8(hex & 0xFF))
    }

    public static let white = RGB(red: 255, green: 255, blue: 255)

    /// Współczynnik kontrastu WCAG 2.x (1...21) między dwoma kolorami.
    public static func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
        let la = a.relativeLuminance, lb = b.relativeLuminance
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Luminancja względna WCAG (sRGB linearyzowane).
    var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let c = Double(channel) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Kolor w wariancie jasnym i ciemnym, zapisany w Assets.xcassets jako `assetName`.
public struct PaletteColor: Equatable, Sendable {
    public var assetName: String
    public var light: RGB
    public var dark: RGB

    public init(assetName: String, light: RGB, dark: RGB) {
        self.assetName = assetName
        self.light = light
        self.dark = dark
    }
}

/// Kolorystyka aplikacji: e-papier (krem i atrament jak ikona) z jednym akcentem terakotowym.
/// Wartości są źródłem prawdy; Assets.xcassets musi im odpowiadać (pilnują tego testy).
public enum AppPalette {
    /// Tło ekranów (kolor ikony i ekranu startowego).
    public static let paper = PaletteColor(assetName: "Paper", light: RGB(hex: 0xF4F1EA), dark: RGB(hex: 0x1C1C1E))
    /// Tło wierszy listy i pól formularza.
    public static let surface = PaletteColor(assetName: "Surface", light: RGB(hex: 0xFBF9F4), dark: RGB(hex: 0x2A2A2C))
    /// Tekst główny.
    public static let ink = PaletteColor(assetName: "Ink", light: RGB(hex: 0x1C1C1E), dark: RGB(hex: 0xF4F1EA))
    /// Tekst pomocniczy (daty, „od innego domownika”, zrobione zadania).
    public static let inkSecondary = PaletteColor(assetName: "InkSecondary", light: RGB(hex: 0x5E5A52), dark: RGB(hex: 0xA9A49A))
    /// Akcent aplikacji (`AccentColor`): przyciski, przełączniki, znaczek oczekujących.
    public static let accent = PaletteColor(assetName: "AccentColor", light: RGB(hex: 0xA8482A), dark: RGB(hex: 0xE9825E))
    /// Komunikaty o błędach.
    public static let danger = PaletteColor(assetName: "Danger", light: RGB(hex: 0xB3261E), dark: RGB(hex: 0xF2B8B5))
    /// Tła akcji przesunięcia (biały napis systemowy), takie same w obu trybach.
    public static let actionComplete = PaletteColor(assetName: "ActionComplete", light: RGB(hex: 0xA8482A), dark: RGB(hex: 0xA8482A))
    public static let actionRestore = PaletteColor(assetName: "ActionRestore", light: RGB(hex: 0x5E5A52), dark: RGB(hex: 0x5E5A52))
    public static let actionDelete = PaletteColor(assetName: "ActionDelete", light: RGB(hex: 0xB3261E), dark: RGB(hex: 0xB3261E))

    public static let all: [PaletteColor] = [
        paper, surface, ink, inkSecondary, accent, danger, actionComplete, actionRestore, actionDelete,
    ]
}
