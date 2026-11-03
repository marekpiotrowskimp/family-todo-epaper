import Foundation
import Testing
@testable import TodoCore

private let appDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("FamilyTodo")

@Suite struct PriorityStyleTests {
    @Test func symbolsMatchTheDisplayIcons() {
        #expect(PriorityStyle.symbolName(for: .high) == "flag.fill")
        #expect(PriorityStyle.symbolName(for: .normal) == "flag")
        #expect(PriorityStyle.symbolName(for: .low) == "minus")
    }

    /// Te same etykiety VoiceOver co w dotychczasowym `PriorityMark`, przeniesione do `TodoCore`.
    @Test func accessibilityLabelsNamePriority() {
        #expect(PriorityStyle.accessibilityLabel(for: .high) == "Wysoki priorytet")
        #expect(PriorityStyle.accessibilityLabel(for: .normal) == "Normalny priorytet")
        #expect(PriorityStyle.accessibilityLabel(for: .low) == "Niski priorytet")
    }

    @Test func everyPriorityHasADistinctVisibleSymbol() {
        let names = Priority.allCases.map(PriorityStyle.symbolName)
        #expect(Set(names).count == Priority.allCases.count)
        #expect(!names.contains(""))
    }

    @Test func appNoLongerUsesDotPriorityMarks() throws {
        let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let sources = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
        let usesCircleSymbols = sources.contains(#"systemName: "circle"#)
        let usesPriorityStyle = sources.contains("PriorityStyle.symbolName")
        #expect(!files.isEmpty)
        #expect(usesCircleSymbols == false)
        #expect(usesPriorityStyle == true)
    }
}
