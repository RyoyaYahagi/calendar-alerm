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

    @Test func sameContentDifferentOrderIsNoOp() {
        let ruleA = UUID()
        let ruleB = UUID()
        let r1 = record(eventID: "E1", fireOffset: 10, ruleID: ruleA)
        let r2 = record(eventID: "E1", fireOffset: 20, ruleID: ruleB)
        let p1 = plan(eventID: "E1", fireOffset: 20, ruleID: ruleB)
        let p2 = plan(eventID: "E1", fireOffset: 10, ruleID: ruleA)
        // existing=[r1,r2], planned=[p1,p2] — 内容同じ・順序逆
        let diff = AlarmDiffer.diff(existing: [r1, r2], planned: [p1, p2])
        #expect(diff.toSchedule.isEmpty)
        #expect(diff.toCancel.isEmpty)
    }

    @Test func partialUpdateCancelsAndSchedulesOnlyChangedEvent() {
        let ruleID = UUID()
        // E1 は変化なし、E2 は fireDate 変更
        let r1 = record(eventID: "E1", fireOffset: 10, ruleID: ruleID)
        let r2 = record(eventID: "E2", fireOffset: 10, ruleID: ruleID)
        let p1 = plan(eventID: "E1", fireOffset: 10, ruleID: ruleID)
        let p2 = plan(eventID: "E2", fireOffset: 20, ruleID: ruleID)
        let diff = AlarmDiffer.diff(existing: [r1, r2], planned: [p1, p2])
        #expect(diff.toCancel.count == 1)
        #expect(diff.toCancel.first == r2.id)
        #expect(diff.toSchedule.count == 1)
        #expect(diff.toSchedule.first?.eventID == "E2")
    }
}
