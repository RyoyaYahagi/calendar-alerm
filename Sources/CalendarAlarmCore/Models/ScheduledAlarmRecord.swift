import Foundation

public struct ScheduledAlarmRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let eventID: String
    public let fireDate: Date
    public let ruleID: UUID

    public init(id: UUID, eventID: String, fireDate: Date, ruleID: UUID) {
        self.id = id
        self.eventID = eventID
        self.fireDate = fireDate
        self.ruleID = ruleID
    }
}
