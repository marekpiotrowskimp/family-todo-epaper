import Foundation

/// Wspólny klucz rodziny (32 B) zapisany jako tekst: 64 znaki hex albo link
/// `familytodo://key?k=<hex>`, który aparat iPhone'a otwiera w aplikacji (kod QR z
/// `tools/make-family-key.sh` albo z ekranu „Klucz rodziny” u domownika).
public enum FamilyKeyCode {
    public static let keyLength = 32
    public static let scheme = "familytodo"
    static let host = "key"
    static let queryItem = "k"

    /// Klucz z tekstu: sam hex (dowolna wielkość liter, spacje, dwukropki i przecinki `0x..`
    /// z pliku nagłówka są pomijane) albo link. Nil, gdy to nie jest dokładnie 32 bajty.
    public static func parse(_ text: String) -> Data? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme?.lowercased() == scheme {
            return key(from: url)
        }
        var hex = trimmed.lowercased().replacingOccurrences(of: "0x", with: "")
        hex.removeAll { " \t\n\r:,;{}-".contains($0) }
        return data(fromHex: hex)
    }

    /// Klucz z linku `familytodo://key?k=<hex>` (nil dla innych linków).
    public static func key(from url: URL) -> Data? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == queryItem })?.value
        else { return nil }
        return data(fromHex: value.lowercased())
    }

    /// Link do kodu QR, który inny telefon zeskanuje aparatem.
    public static func url(for key: Data) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: queryItem, value: hex(key))]
        return components.url!
    }

    public static func hex(_ key: Data) -> String {
        key.map { String(format: "%02x", $0) }.joined()
    }

    private static func data(fromHex hex: String) -> Data? {
        guard hex.count == keyLength * 2, hex.allSatisfy(\.isHexDigit) else { return nil }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }
}
