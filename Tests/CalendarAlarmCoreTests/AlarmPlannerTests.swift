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

    @Test func multipleMatchingRulesProduceMultipleAlarms() {
        let now = Date(timeIntervalSince1970: 0)
        let start = now.addingTimeInterval(3600)
        let event = CalendarEvent(
            id: "E1",
            title: "meeting",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            source: .apple
        )
        let rule10 = AlarmRule(keywords: ["meeting"], matchMode: .any, leadMinutes: 10)
        let rule30 = AlarmRule(keywords: ["meeting"], matchMode: .any, leadMinutes: 30)
        let alarms = AlarmPlanner.plan(events: [event], rules: [rule10, rule30], now: now)
        #expect(alarms.count == 2)
        let fireDates = Set(alarms.map(\.fireDate))
        #expect(fireDates.count == 2)
    }

    @Test func duplicateLeadMinutesDeduplicates() {
        let now = Date(timeIntervalSince1970: 0)
        let start = now.addingTimeInterval(3600)
        let event = CalendarEvent(
            id: "E2",
            title: "meeting",
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            source: .apple
        )
        // 同じ leadMinutes のルールが2つ → fireDate が同じなので1件に圧縮
        let ruleA = AlarmRule(keywords: ["meeting"], matchMode: .any, leadMinutes: 15)
        let ruleB = AlarmRule(keywords: ["meeting"], matchMode: .any, leadMinutes: 15)
        let alarms = AlarmPlanner.plan(events: [event], rules: [ruleA, ruleB], now: now)
        #expect(alarms.count == 1)
    }

    @Test func returnsEmptyWhenNoRulesMatch() {
        let event = event(title: "Lunch", startOffsetMinutes: 60)
        let rule = AlarmRule(keywords: ["会議"], leadMinutes: 15)
        let plans = AlarmPlanner.plan(events: [event], rules: [rule], now: baseDate)
        #expect(plans.isEmpty)
    }
}
