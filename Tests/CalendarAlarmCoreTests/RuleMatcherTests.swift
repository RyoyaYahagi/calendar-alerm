import Foundation
import Testing
@testable import CalendarAlarmCore

struct RuleMatcherTests {
    func makeEvent(title: String, notes: String? = nil) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: title,
            notes: notes,
            startDate: Date(),
            endDate: Date(),
            source: .apple
        )
    }

    func makeRule(keywords: [String], matchMode: MatchMode = .any) -> AlarmRule {
        AlarmRule(keywords: keywords, matchMode: matchMode, leadMinutes: 10)
    }

    @Test func keywordMatchInTitle() {
        let event = makeEvent(title: "会議 with customer")
        let rule = makeRule(keywords: ["会議"])
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func keywordMatchInNotes() {
        let event = makeEvent(title: "Team sync", notes: "Important 会議")
        let rule = makeRule(keywords: ["会議"])
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func caseInsensitiveMatch() {
        let event = makeEvent(title: "MEETING")
        let rule = makeRule(keywords: ["meeting"])
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func noMatch() {
        let event = makeEvent(title: "Lunch break")
        let rule = makeRule(keywords: ["会議"])
        #expect(RuleMatcher.matches(event: event, rule: rule) == false)
    }

    @Test func emptyKeywordsReturnsFalse() {
        let event = makeEvent(title: "Anything")
        let rule = makeRule(keywords: [""])
        #expect(RuleMatcher.matches(event: event, rule: rule) == false)
    }

    @Test func emojiKeywordMatch() {
        let event = makeEvent(title: "🎉 Party meeting 🎉")
        let rule = makeRule(keywords: ["Party"])
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func anyModeMatchesOneOfMultiple() {
        let event = makeEvent(title: "Project review")
        let rule = makeRule(keywords: ["会議", "review"], matchMode: .any)
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func anyModeMatchesNone() {
        let event = makeEvent(title: "Coffee break")
        let rule = makeRule(keywords: ["会議", "review"], matchMode: .any)
        #expect(RuleMatcher.matches(event: event, rule: rule) == false)
    }

    @Test func allModeMatchesAll() {
        let event = makeEvent(title: "Project review meeting")
        let rule = makeRule(keywords: ["Project", "review"], matchMode: .all)
        #expect(RuleMatcher.matches(event: event, rule: rule) == true)
    }

    @Test func allModeMissingOne() {
        let event = makeEvent(title: "Project standup")
        let rule = makeRule(keywords: ["Project", "review"], matchMode: .all)
        #expect(RuleMatcher.matches(event: event, rule: rule) == false)
    }
}
