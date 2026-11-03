import Foundation
@testable import TodoCore

func ms(_ value: Int64) -> Date {
    Date(timeIntervalSince1970: Double(value) / 1000)
}

func makeTask(
    _ id: String,
    owner: String = "anna",
    priority: Priority = .normal,
    due: Int64? = nil,
    created: Int64 = 1000,
    updated: Int64 = 1000,
    by: String? = nil,
    status: TaskStatus = .active,
    reminder: Int64? = nil,
    deleted: Bool = false
) -> TodoTask {
    TodoTask(
        id: id,
        ownerId: owner,
        title: "Zadanie \(id)",
        priority: priority,
        dueAt: due.map(ms),
        status: status,
        reminderAt: reminder.map(ms),
        createdAt: ms(created),
        updatedAt: ms(updated),
        updatedBy: by ?? owner,
        deleted: deleted
    )
}

final class TestClock: @unchecked Sendable {
    var now: Date

    init(_ start: Int64 = 1_793_430_000_000) {
        now = ms(start)
    }

    func advance(ms value: Int64) {
        now = now.addingTimeInterval(Double(value) / 1000)
    }
}

func sequentialIDs() -> () -> String {
    var n = 0
    return {
        n += 1
        return "id-\(n)"
    }
}

/// Wspólne z firmware (test/helpers/hex.h, test_auth, test_session).
enum Vectors {
    /// Klucz rodziny w testach (00..1f).
    static let secret = Data((0..<32).map { UInt8($0) })
    static let nonce = Data((0xa0...0xaf).map { UInt8($0) })
    static let annaMacHex = "fac4725981f6273e72f559d39aaaf01973375f67fe07269384b8c32f2241fd4a"
    static let zanetaMacHex = "4ad03de7d04e042582a05dd151c36af6a5688c3af407c279a64c1464b58a1e88"
    static var annaMac: Data { Data(hex: annaMacHex) }
}

extension Data {
    init(hex: String) {
        var bytes: [UInt8] = []
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            bytes.append(UInt8(hex[i..<j], radix: 16) ?? 0)
            i = j
        }
        self.init(bytes)
    }

    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

func jsonObject(_ data: Data) -> NSDictionary? {
    (try? JSONSerialization.jsonObject(with: data)) as? NSDictionary
}

func jsonObject(_ string: String) -> NSDictionary? {
    jsonObject(Data(string.utf8))
}

func temporaryFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("TodoCoreTests-\(UUID().uuidString)")
        .appendingPathComponent("tasks.json")
}
