import Foundation

/// Ikony priorytetu w aplikacji (SF Symbols), te same znaczenia co na e-papierze
/// (`todo::priorityIcon`): pełna flaga = wysoki, flaga w obrysie = normalny, kreska = niski.
public enum PriorityStyle {
    public static func symbolName(for priority: Priority) -> String {
        switch priority {
        case .high: "flag.fill"
        case .normal: "flag"
        case .low: "minus"
        }
    }

    public static func accessibilityLabel(for priority: Priority) -> String {
        switch priority {
        case .high: "Wysoki priorytet"
        case .normal: "Normalny priorytet"
        case .low: "Niski priorytet"
        }
    }
}
