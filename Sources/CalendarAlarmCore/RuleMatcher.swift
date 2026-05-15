import Foundation

public struct RuleMatcher: Sendable {
    public static func matches(event: CalendarEvent, rule: AlarmRule) -> Bool {
        let text = [event.title, event.notes].compactMap { $0 }.joined(separator: " ")
        let keywords = rule.keywords.filter { !$0.isEmpty }
        guard !keywords.isEmpty else { return false }

        switch rule.matchMode {
        case .any:
            return keywords.contains { text.localizedCaseInsensitiveContains($0) }
        case .all:
            return keywords.allSatisfy { text.localizedCaseInsensitiveContains($0) }
        }
    }
}
