import Foundation

public struct AlarmPlanner: Sendable {
    public static func plan(events: [CalendarEvent], rules: [AlarmRule], now: Date) -> [PlannedAlarm] {
        var result: [PlannedAlarm] = []
        for event in events {
            guard !event.isAllDay else { continue }
            let matchingRules = rules.filter {
                $0.enabled && $0.sources.contains(event.source) && RuleMatcher.matches(event: event, rule: $0)
            }
            guard let bestRule = matchingRules.min(by: { $0.leadMinutes < $1.leadMinutes }) else { continue }
            let fireDate = event.startDate.addingTimeInterval(-TimeInterval(bestRule.leadMinutes * 60))
            guard fireDate > now else { continue }
            result.append(PlannedAlarm(
                eventID: event.id,
                fireDate: fireDate,
                ruleID: bestRule.id,
                title: event.title,
                soundID: bestRule.soundID
            ))
        }
        return result
    }
}
