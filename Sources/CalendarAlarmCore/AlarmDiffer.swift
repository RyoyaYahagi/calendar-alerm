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
    public static func diff(existing: [ScheduledAlarmRecord], planned: [PlannedAlarm]) -> AlarmDiff {
        let existingByEvent = Dictionary(grouping: existing, by: \.eventID)
        let plannedByEvent = Dictionary(grouping: planned, by: \.eventID)

        var toCancel: [UUID] = []
        var toSchedule: [PlannedAlarm] = []

        for (eventID, records) in existingByEvent {
            if let plans = plannedByEvent[eventID] {
                // Both exist: compare. If any mismatch, cancel all existing and schedule all planned.
                let needsUpdate = zip(records, plans).contains { $0.fireDate != $1.fireDate || $0.ruleID != $1.ruleID }
                    || records.count != plans.count
                if needsUpdate {
                    toCancel.append(contentsOf: records.map(\.id))
                    toSchedule.append(contentsOf: plans)
                }
            } else {
                // No longer planned → cancel
                toCancel.append(contentsOf: records.map(\.id))
            }
        }

        for (eventID, plans) in plannedByEvent {
            if existingByEvent[eventID] == nil {
                // New plan → schedule
                toSchedule.append(contentsOf: plans)
            }
            // Update case is already handled above
        }

        return AlarmDiff(toSchedule: toSchedule, toCancel: toCancel)
    }
}
