#if canImport(UIKit)
import Foundation
import Observation

@MainActor
@Observable
final class SyncStore {
    private(set) var isSyncing = false
    private(set) var lastSyncDate: Date?
    private(set) var lastError: Error?

    private let coordinator: SyncCoordinator
    private let ruleStore: RuleStore

    init(coordinator: SyncCoordinator, ruleStore: RuleStore) {
        self.coordinator = coordinator
        self.ruleStore = ruleStore
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }
        do {
            try await coordinator.sync(rules: ruleStore.rules)
            lastSyncDate = .now
        } catch {
            lastError = error
        }
    }
}
#endif
