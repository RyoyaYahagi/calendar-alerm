#if canImport(UIKit)
import Foundation
import UserNotifications
import CalendarAlarmCore

// AlarmKit は iOS 26+ でのみ利用可能
#if canImport(AlarmKit)
import AlarmKit
#endif

/// アラームの登録・解除と ScheduledAlarmRecord の永続化を担う
struct AlarmScheduler {
    private static let recordsKey = "scheduledAlarmRecords"

    // MARK: - Apply diff

    func apply(diff: AlarmDiff) async throws {
        try await cancel(ids: diff.toCancel)
        try await schedule(alarms: diff.toSchedule)
        updateRecords(diff: diff)
    }

    // MARK: - Current records

    func loadRecords() -> [ScheduledAlarmRecord] {
        guard let data = UserDefaults.standard.data(forKey: Self.recordsKey),
              let records = try? JSONDecoder().decode([ScheduledAlarmRecord].self, from: data)
        else { return [] }
        return records
    }

    // MARK: - Private helpers

    private func schedule(alarms: [PlannedAlarm]) async throws {
#if canImport(AlarmKit)
        if #available(iOS 26, *) {
            try await scheduleWithAlarmKit(alarms)
            return
        }
#endif
        try await scheduleWithUNNotifications(alarms)
    }

    private func cancel(ids: [UUID]) async throws {
#if canImport(AlarmKit)
        if #available(iOS 26, *) {
            try await cancelWithAlarmKit(ids)
            return
        }
#endif
        cancelWithUNNotifications(ids)
    }

    // MARK: - AlarmKit (iOS 26+)

#if canImport(AlarmKit)
    @available(iOS 26, *)
    private func scheduleWithAlarmKit(_ alarms: [PlannedAlarm]) async throws {
        for alarm in alarms {
            let attributes = AlarmAttributes(
                label: alarm.title,
                sound: AlarmAttributes.Sound(name: alarm.soundID)
            )
            let schedule = AlarmSchedule.fixedDate(alarm.fireDate)
            let ak = Alarm(id: alarm.id.uuidString, schedule: schedule, attributes: attributes)
            try await AlarmManager.shared.add(ak)
        }
    }

    @available(iOS 26, *)
    private func cancelWithAlarmKit(_ ids: [UUID]) async throws {
        let stringIDs = ids.map(\.uuidString)
        try await AlarmManager.shared.removeAlarms(withIDs: stringIDs)
    }
#endif

    // MARK: - UserNotifications fallback

    private func scheduleWithUNNotifications(_ alarms: [PlannedAlarm]) async throws {
        let center = UNUserNotificationCenter.current()
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        for alarm in alarms {
            let content = UNMutableNotificationContent()
            content.title = alarm.title
            content.sound = alarm.soundID == "default" ? .defaultCritical : UNNotificationSound(named: UNNotificationSoundName(alarm.soundID))
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alarm.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
            try await center.add(request)
        }
    }

    private func cancelWithUNNotifications(_ ids: [UUID]) {
        let stringIDs = ids.map(\.uuidString)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stringIDs)
    }

    // MARK: - Record persistence

    private func updateRecords(diff: AlarmDiff) {
        var records = loadRecords()
        let cancelSet = Set(diff.toCancel)
        records.removeAll { cancelSet.contains($0.id) }
        let newRecords = diff.toSchedule.map { planned in
            ScheduledAlarmRecord(
                id: planned.id,
                eventID: planned.eventID,
                fireDate: planned.fireDate,
                ruleID: planned.ruleID
            )
        }
        records.append(contentsOf: newRecords)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: Self.recordsKey)
        }
    }
}
#endif
