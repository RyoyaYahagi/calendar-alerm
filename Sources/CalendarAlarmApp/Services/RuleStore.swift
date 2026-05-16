#if canImport(UIKit)
import Foundation
import SwiftData
import Observation
import CalendarAlarmCore

@MainActor
@Observable
final class RuleStore {
    private let context: ModelContext
    private(set) var rules: [AlarmRule] = []

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: - Read

    func reload() {
        let entities = (try? context.fetch(FetchDescriptor<AlarmRuleEntity>())) ?? []
        rules = entities.map(\.asAlarmRule)
    }

    // MARK: - Write

    func add(_ rule: AlarmRule) throws {
        context.insert(AlarmRuleEntity(rule))
        try context.save()
        reload()
    }

    func update(_ rule: AlarmRule) throws {
        let descriptor = FetchDescriptor<AlarmRuleEntity>(
            predicate: #Predicate { $0.id == rule.id }
        )
        guard let entity = try context.fetch(descriptor).first else { return }
        entity.update(from: rule)
        try context.save()
        reload()
    }

    func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<AlarmRuleEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else { return }
        context.delete(entity)
        try context.save()
        reload()
    }
}
#endif
