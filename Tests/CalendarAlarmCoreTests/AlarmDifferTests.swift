import Foundation
import Testing
@testable import CalendarAlarmCore

struct AlarmDifferTests {
    let base = Date(timeIntervalSince1970: 1_000_000)

    func record(eventID: String, fireOffset: Int, ruleID: UUID = UUID()) -> ScheduledAlarmRecord {
        ScheduledAlarmRecord(
            id: UUID(),
            eventID: eventID,
            fireDate: base.addingTimeInterval(TimeInterval(fireOffset * 60)),
            ruleID: ruleID
        )
    }

    func plan(eventID: String, fireOffset: Int, ruleID: UUID = UUID()) -> PlannedAlarm {
        PlannedAlarm(
            eventID: eventID,
            fireDate: base.addingTimeInterval(TimeInterval(fireOffset * 60)),
            ruleID: ruleID,
            title: "Event",
            soundID: "default"
        )
    }

    @Test func emptyArraysReturnEmptyDiff() {
        let diff = AlarmDiffer.diff(existing: [], planned: [])
        #expect(diff.toSchedule.isEmpty)
        #expect(diff.toCancel.isEmpty)
    }

    @Test func newPlanIsToSchedule() {
        let p = plan(eventID: "E1", fireOffset: 10)
        let diff = AlarmDiffer.diff(existing: [], planned: [p])
        #expect(diff.toSchedule.count == 1)
        #expect(diff.toCancel.isEmpty)
        #expect(diff.toSchedule.first?.eventID == "E1")
    }

    @Test func removedPlanIsToCancel() {
        let r = record(eventID: "E1", fireOffset: 10)
        let diff = AlarmDiffer.diff(existing: [r], planned: [])
        #expect(diff.toSchedule.isEmpty)
        #expect(diff.toCancel.count == 1)
        #expect(diff.toCancel.first == r.id)
    }

    @Test func unchangedPlanIsNoOp() {
        let ruleID = UUID()
        let r = record(eventID: "E1", fireOffset: 10, ruleID: ruleID)
        let p = plan(eventID: "E1", fireOffset: 10, ruleID: ruleID)
        let diff = AlarmDiffer.diff(existing: [r], planned: [p])
        #expect(diff.toSchedule.isEmpty)
        #expect(diff.toCancel.isEmpty)
    }

    @Test func fireDateChangeIsCancelAndSchedule() {
        let ruleID = UUID()
        let r = record(eventID: "E1", fireOffset: 10, ruleID: ruleID)
        let p = plan(eventID: "E1", fireOffset: 20, ruleID: ruleID)
        let diff = AlarmDiffer.diff(existing: [r], planned: [p])
        #expect(diff.toSchedule.count == 1)
        #expect(diff.toCancel.count == 1)
        #expect(diff.toCancel.first == r.id)
        #expect(diff.toSchedule.first?.fireDate == p.fireDate)
    }

    @Test func ruleIDChangeIsCancelAndSchedule() {
        let r = record(eventID: "E1", fireOffset: 10, ruleID: UUID())
        let p = plan(eventID: "E1", fireOffset: 10, ruleID: UUID())
        let diff = AlarmDiffer.diff(existing: [r], planned: [p])
        #expect(diff.toSchedule.count == 1)
        #expect(diff.toCancel.count == 1)
        #expect(diff.toCancel.first == r.id)
    }
}
