import Foundation

public struct PlannedAlarm: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let eventID: String
    public let fireDate: Date
    public let ruleID: UUID
    public let title: String
    public let soundID: String

    public init(
        id: UUID = UUID(),
        eventID: String,
        fireDate: Date,
        ruleID: UUID,
        title: String,
        soundID: String
    ) {
        self.id = id
        self.eventID = eventID
        self.fireDate = fireDate
        self.ruleID = ruleID
        self.title = title
        self.soundID = soundID
    }
}
