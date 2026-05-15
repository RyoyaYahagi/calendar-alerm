import Foundation

public struct AlarmDiff: Sendable, Equatable {
    public let toSchedule: [PlannedAlarm]
    public let toCancel: [UUID]

    public init(toSchedule: [PlannedAlarm] = [], toCancel: [UUID] = []) {
        self.toSchedule = toSchedule
        self.toCancel = toCancel
    }
}

public struct AlarmDiffer: Sendable {
    // (fireDate, ruleID) の組をキーにして比較する内部型
    private struct AlarmKey: Hashable {
        let fireDate: Date
        let ruleID: UUID
    }

    public static func diff(existing: [ScheduledAlarmRecord], planned: [PlannedAlarm]) -> AlarmDiff {
        let existingByEvent = Dictionary(grouping: existing, by: \.eventID)
        let plannedByEvent  = Dictionary(grouping: planned,  by: \.eventID)

        var toCancel:   [UUID]         = []
        var toSchedule: [PlannedAlarm] = []

        let allEventIDs = Set(existingByEvent.keys).union(plannedByEvent.keys)

        for eventID in allEventIDs {
            let records = existingByEvent[eventID] ?? []
            let plans   = plannedByEvent[eventID]  ?? []

            let existingKeys = Set(records.map { AlarmKey(fireDate: $0.fireDate, ruleID: $0.ruleID) })
            let plannedKeys  = Set(plans.map   { AlarmKey(fireDate: $0.fireDate, ruleID: $0.ruleID) })

            if existingKeys == plannedKeys { continue } // 変更なし

            // 差分がある → このイベントのアラームをすべて入れ替え
            toCancel.append(contentsOf: records.map(\.id))
            toSchedule.append(contentsOf: plans)
        }

        return AlarmDiff(toSchedule: toSchedule, toCancel: toCancel)
    }
}
