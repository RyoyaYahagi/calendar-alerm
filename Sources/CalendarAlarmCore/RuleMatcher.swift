import Foundation

public struct RuleMatcher: Sendable {
    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    public static func matches(event: CalendarEvent, rule: AlarmRule) -> Bool {
        let text = normalize([event.title, event.notes].compactMap { $0 }.joined(separator: " "))
        let keywords = rule.keywords.filter { !$0.isEmpty }
        guard !keywords.isEmpty else { return false }

        switch rule.matchMode {
        case .any:
            return keywords.contains { text.contains(normalize($0)) }
        case .all:
            return keywords.allSatisfy { text.contains(normalize($0)) }
        }
    }
}
