import Foundation

public struct AlarmPlanner: Sendable {
    public static func plan(events: [CalendarEvent], rules: [AlarmRule], now: Date) -> [PlannedAlarm] {
        var result: [PlannedAlarm] = []

        for event in events {
            guard !event.isAllDay else { continue }

            let matchingRules = rules.filter {
                $0.enabled && $0.sources.contains(event.source) && RuleMatcher.matches(event: event, rule: $0)
            }

            // 同一 (eventID, fireDate) の重複を除去しながら全ルール分生成
            var seenFireDates = Set<TimeInterval>()
            for rule in matchingRules {
                let fireDate = event.startDate.addingTimeInterval(-TimeInterval(rule.leadMinutes * 60))
                guard fireDate > now else { continue }
                guard seenFireDates.insert(fireDate.timeIntervalSince1970).inserted else { continue }
                result.append(PlannedAlarm(
                    eventID: event.id,
                    fireDate: fireDate,
                    ruleID: rule.id,
                    title: event.title,
                    soundID: rule.soundID
                ))
            }
        }

        return result
    }
}
