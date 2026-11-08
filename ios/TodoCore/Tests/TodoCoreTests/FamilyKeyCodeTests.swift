import Foundation
import Testing
@testable import TodoCore

/// Klucz rodziny wpisywany w aplikacji: hex, link z kodu QR i treść pliku family_key.h.
@Suite struct FamilyKeyCodeTests {
    let key = Data((0..<32).map { UInt8($0 * 7 & 0xff) })
    var hex: String { FamilyKeyCode.hex(key) }

    @Test func hexIs64LowercaseCharacters() {
        #expect(hex.count == 64)
        #expect(hex == hex.lowercased())
        #expect(hex.hasPrefix("00070e15"))
    }

    @Test func parsesPlainHexInAnyCaseWithSurroundingWhitespace() {
        #expect(FamilyKeyCode.parse(hex) == key)
        #expect(FamilyKeyCode.parse("  \(hex.uppercased())\n") == key)
    }

    @Test func parsesBytesCopiedFromTheFirmwareHeader() {
        let header = "{" + key.map { String(format: "0x%02X", $0) }.joined(separator: ", ") + "};"
        #expect(FamilyKeyCode.parse(header) == key)
    }

    @Test func urlRoundTrips() {
        let url = FamilyKeyCode.url(for: key)
        #expect(url.absoluteString == "familytodo://key?k=\(hex)")
        #expect(FamilyKeyCode.key(from: url) == key)
        #expect(FamilyKeyCode.parse(url.absoluteString) == key)
    }

    @Test func rejectsWrongLengthAndNonHex() {
        #expect(FamilyKeyCode.parse(String(hex.dropLast(2))) == nil)
        #expect(FamilyKeyCode.parse(hex + "00") == nil)
        #expect(FamilyKeyCode.parse(String(hex.dropLast()) + "g") == nil)
        #expect(FamilyKeyCode.parse("") == nil)
    }

    @Test func rejectsOtherLinks() {
        #expect(FamilyKeyCode.key(from: URL(string: "familytodo://other?k=\(hex)")!) == nil)
        #expect(FamilyKeyCode.key(from: URL(string: "https://key?k=\(hex)")!) == nil)
        #expect(FamilyKeyCode.key(from: URL(string: "familytodo://key")!) == nil)
    }
}
