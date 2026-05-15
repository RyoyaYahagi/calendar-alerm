import Foundation
import Testing
@testable import CalendarAlarmCore

struct AlarmPlannerTests {
    let baseDate = Date(timeIntervalSince1970: 1_000_000)

    func event(title: String, startOffsetMinutes: Int, isAllDay: Bool = false, source: SourceKind = .apple) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: baseDate.addingTimeInterval(TimeInterval(startOffsetMinutes * 60)),
            endDate: baseDate.addingTimeInterval(TimeInterval((startOffsetMinutes + 30) * 60)),
            isAllDay: isAllDay,
            source: source
        )
    }

    @Test func plansAlarmBeforeEvent() {
        let event = event(title: "会議", startOffsetMinutes: 60)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.count == 1)
        #expect(plans.first?.fireDate == baseDate.addingTimeInterval(45 * 60))
    }

    @Test func skipsPastEvents() {
        let event = event(title: "会議", startOffsetMinutes: -10)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }

    @Test func skipsAllDayEvents() {
        let event = event(title: "Holiday", startOffsetMinutes: 60, isAllDay: true)
        let rule = AlarmRule(keywords: ["Holiday"], leadMinutes: 15)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }

    @Test func skipsDisabledRules() {
        let event = event(title: "会議", startOffsetMinutes: 60)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15, enabled: false)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }

    @Test func skipsNonMatchingSource() {
        let event = event(title: "会議", startOffsetMinutes: 60, source: .google)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15, sources: [.apple])
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }

    @Test func picksShortestLeadTimeOnMultipleMatches() {
        let event = event(title: "会議", startOffsetMinutes: 60)
        let ruleA = AlarmRule(keywords: ["会議"], leadMinutes: 30)
        let ruleB = AlarmRule(keywords: ["会議"], leadMinutes: 10)
        let plans = AlarmPlanner.plan(events: [event], rules: [ruleA, ruleB], now: baseDate)
        #expect(plans.count == 1)
        #expect(plans.first?.fireDate == baseDate.addingTimeInterval(50 * 60))
        #expect(plans.first?.ruleID == ruleB.id)
    }

    @Test func returnsEmptyWhenNoRulesMatch() {
        let event = event(title: "Lunch", startOffsetMinutes: 60)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }
}
