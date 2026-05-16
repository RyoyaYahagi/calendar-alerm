#if canImport(UIKit)
import Foundation
import SwiftData
import CalendarAlarmCore

/// AlarmRule の SwiftData 永続化エンティティ
/// @Model は class かつ Codable 非対応のため、値型の AlarmRule と相互変換する
@Model
final class AlarmRuleEntity {
    var id: UUID
    var keywords: [String]
    var matchModeRaw: String
    var leadMinutes: Int
    var isEnabled: Bool
    var soundID: String
    /// SourceKind.rawValue の配列 (Set<SourceKind> は SwiftData 非対応のため [String] で保持)
    var sourcesRaw: [String]

    init(_ rule: AlarmRule) {
        self.id           = rule.id
        self.keywords     = rule.keywords
        self.matchModeRaw = rule.matchMode.rawValue
        self.leadMinutes  = rule.leadMinutes
        self.isEnabled    = rule.enabled
        self.soundID      = rule.soundID
        self.sourcesRaw   = rule.sources.map(\.rawValue)
    }

    var asAlarmRule: AlarmRule {
        AlarmRule(
            id:          id,
            keywords:    keywords,
            matchMode:   MatchMode(rawValue: matchModeRaw) ?? .any,
            leadMinutes: leadMinutes,
            enabled:     isEnabled,
            soundID:     soundID,
            sources:     Set(sourcesRaw.compactMap(SourceKind.init(rawValue:)))
        )
    }

    func update(from rule: AlarmRule) {
        keywords     = rule.keywords
        matchModeRaw = rule.matchMode.rawValue
        leadMinutes  = rule.leadMinutes
        isEnabled    = rule.enabled
        soundID      = rule.soundID
        sourcesRaw   = rule.sources.map(\.rawValue)
    }
}
#endif
