import Foundation
import Testing
@testable import TodoCore

/// Katalog ios/ (testy leżą w ios/TodoCore/Tests/TodoCoreTests).
private let iosDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
private let appDirectory = iosDirectory.appendingPathComponent("FamilyTodo")
private let assetsDirectory = appDirectory.appendingPathComponent("Assets.xcassets")

private func rgb(_ hex: UInt32) -> RGB {
    RGB(red: UInt8(hex >> 16 & 0xFF), green: UInt8(hex >> 8 & 0xFF), blue: UInt8(hex & 0xFF))
}

/// Odczyt kolorsetu Xcode: wpis bez `appearances` = jasny, z `luminosity: dark` = ciemny.
/// Składowe jako ułamki ("0.957") albo hex ("0xF4").
private func colorset(_ name: String) throws -> (light: RGB?, dark: RGB?) {
    let url = assetsDirectory.appendingPathComponent("\(name).colorset/Contents.json")
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    let colors = try #require(object?["colors"] as? [[String: Any]])
    var light: RGB?
    var dark: RGB?
    for entry in colors {
        let components = try #require((entry["color"] as? [String: Any])?["components"] as? [String: String])
        func channel(_ key: String) throws -> UInt8 {
            let raw = try #require(components[key])
            if raw.hasPrefix("0x") { return try #require(UInt8(raw.dropFirst(2), radix: 16)) }
            return UInt8((try #require(Double(raw)) * 255).rounded())
        }
        let color = RGB(red: try channel("red"), green: try channel("green"), blue: try channel("blue"))
        let appearances = entry["appearances"] as? [[String: String]] ?? []
        if appearances.contains(where: { $0["appearance"] == "luminosity" && $0["value"] == "dark" }) {
            dark = color
        } else {
            light = color
        }
    }
    return (light, dark)
}

@Suite struct AppPaletteTests {
    @Test func paletteValuesMatchTheChosenTerracottaOnPaperScheme() {
        let expected: [(PaletteColor, UInt32, UInt32)] = [
            (AppPalette.paper, 0xF4F1EA, 0x1C1C1E),
            (AppPalette.surface, 0xFBF9F4, 0x2A2A2C),
            (AppPalette.ink, 0x1C1C1E, 0xF4F1EA),
            (AppPalette.inkSecondary, 0x5E5A52, 0xA9A49A),
            (AppPalette.accent, 0xA8482A, 0xE9825E),
            (AppPalette.danger, 0xB3261E, 0xF2B8B5),
            (AppPalette.actionComplete, 0xA8482A, 0xA8482A),
            (AppPalette.actionRestore, 0x5E5A52, 0x5E5A52),
            (AppPalette.actionDelete, 0xB3261E, 0xB3261E),
        ]
        for (color, light, dark) in expected {
            #expect(color.light == rgb(light), "\(color.assetName) jasny")
            #expect(color.dark == rgb(dark), "\(color.assetName) ciemny")
        }
        #expect(AppPalette.all.map(\.assetName) == [
            "Paper", "Surface", "Ink", "InkSecondary", "AccentColor", "Danger",
            "ActionComplete", "ActionRestore", "ActionDelete",
        ])
    }

    @Test func hexInitializerReadsRRGGBB() {
        #expect(RGB(hex: 0xA8482A) == RGB(red: 0xA8, green: 0x48, blue: 0x2A))
    }

    @Test func contrastRatioFollowsWCAG() {
        #expect(abs(RGB.contrastRatio(.white, rgb(0x000000)) - 21) < 0.01)
        #expect(abs(RGB.contrastRatio(rgb(0x777777), .white) - 4.48) < 0.01)  // przykład z WCAG
        #expect(RGB.contrastRatio(rgb(0x123456), rgb(0x123456)) == 1)
    }

    @Test(arguments: [AppPalette.ink, AppPalette.inkSecondary, AppPalette.accent, AppPalette.danger])
    func textColorsAreReadableOnBackgroundsInBothModes(color: PaletteColor) {
        for background in [AppPalette.paper, AppPalette.surface] {
            #expect(RGB.contrastRatio(color.light, background.light) >= 4.5, "\(color.assetName) na \(background.assetName), jasny")
            #expect(RGB.contrastRatio(color.dark, background.dark) >= 4.5, "\(color.assetName) na \(background.assetName), ciemny")
        }
    }

    @Test(arguments: [AppPalette.actionComplete, AppPalette.actionRestore, AppPalette.actionDelete])
    func swipeActionFillsKeepWhiteLabelReadable(color: PaletteColor) {
        #expect(color.light == color.dark)
        #expect(RGB.contrastRatio(.white, color.light) >= 4.5, "\(color.assetName)")
    }

    @Test func assetCatalogMatchesPalette() throws {
        for color in AppPalette.all {
            let set = try colorset(color.assetName)
            #expect(set.light == color.light, "\(color.assetName).colorset jasny")
            #expect(set.dark == color.dark, "\(color.assetName).colorset ciemny")
        }
    }

    @Test func accentColorAssetIsTheGlobalAccent() throws {
        let spec = try String(contentsOf: iosDirectory.appendingPathComponent("project.yml"), encoding: .utf8)
        #expect(spec.contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor"))
    }

    @Test func viewsUseNoSystemNamedColors() throws {
        let pattern = try NSRegularExpression(
            pattern: #"\.(red|green|orange|blue|yellow|pink|purple|mint|teal|cyan|indigo|brown)\b"#)
        let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in pattern.matches(in: source, range: range) {
                offenders.append("\(file.lastPathComponent): \((source as NSString).substring(with: match.range))")
            }
        }
        #expect(offenders == [])
    }

    /// Charakteryzacja: ekran startowy ma już kolor papieru i ma go zachować.
    @Test func launchBackgroundStaysPaperColored() throws {
        let set = try colorset("LaunchBackground")
        #expect(set.light == RGB(red: 0xF4, green: 0xF1, blue: 0xEA))
        #expect(set.dark == RGB(red: 0x1C, green: 0x1C, blue: 0x1E))
    }
}
