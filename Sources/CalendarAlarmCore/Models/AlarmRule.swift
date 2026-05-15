import Foundation

public enum MatchMode: String, Codable, Sendable {
    case any
    case all
}

public struct AlarmRule: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public var keywords: [String]
    public var matchMode: MatchMode
    public var leadMinutes: Int
    public var enabled: Bool
    public var soundID: String
    public var sources: Set<SourceKind>

    public init(
        id: UUID = UUID(),
        keywords: [String],
        matchMode: MatchMode = .any,
        leadMinutes: Int,
        enabled: Bool = true,
        soundID: String = "default",
        sources: Set<SourceKind> = Set(SourceKind.allCases)
    ) {
        self.id = id
        self.keywords = keywords
        self.matchMode = matchMode
        self.leadMinutes = leadMinutes
        self.enabled = enabled
        self.soundID = soundID
        self.sources = sources
    }
}
