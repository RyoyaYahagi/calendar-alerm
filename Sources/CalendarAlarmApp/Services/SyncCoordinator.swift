#if canImport(UIKit)
import Foundation
import CalendarAlarmCore

struct SyncCoordinator: Sendable {
    let sources: [any CalendarSource]
    let scheduler: AlarmScheduler

    /// 今日から 30 日先までを同期ウィンドウとする
    private static let horizonDays: TimeInterval = 30 * 24 * 3_600

    func sync(rules: [AlarmRule]) async throws {
        let now = Date.now
        let horizon = now.addingTimeInterval(Self.horizonDays)

        // 1. 全ソースから並行取得
        let events = try await fetchAll(from: now, to: horizon)

        // 2. アラーム計画
        let planned = AlarmPlanner.plan(events: events, rules: rules, now: now)

        // 3. 既存レコードとの差分
        let existing = scheduler.loadRecords()
        let diff = AlarmDiffer.diff(existing: existing, planned: planned)

        // 4. AlarmKit へ反映
        try await scheduler.apply(diff: diff)
    }

    private func fetchAll(from start: Date, to end: Date) async throws -> [CalendarEvent] {
        try await withThrowingTaskGroup(of: [CalendarEvent].self) { group in
            for source in sources {
                group.addTask { try await source.fetchEvents(from: start, to: end) }
            }
            var all: [CalendarEvent] = []
            for try await batch in group { all.append(contentsOf: batch) }
            return all
        }
    }
}
#endif
