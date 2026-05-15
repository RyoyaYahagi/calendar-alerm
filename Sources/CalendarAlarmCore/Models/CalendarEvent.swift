import Foundation

public struct CalendarEvent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let notes: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let source: SourceKind

    public init(
        id: String,
        title: String,
        notes: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        source: SourceKind
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.source = source
    }
}
