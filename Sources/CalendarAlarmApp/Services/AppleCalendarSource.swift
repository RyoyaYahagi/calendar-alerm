#if canImport(UIKit)
import EventKit
import CalendarAlarmCore

struct AppleCalendarSource: CalendarSource {
    private let store = EKEventStore()

    func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarEvent] {
        try await requestAccess()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map(CalendarEvent.init(ekEvent:))
    }

    private func requestAccess() async throws {
        if #available(iOS 17, *) {
            guard try await store.requestFullAccessToEvents() else {
                throw CalendarSourceError.accessDenied
            }
        } else {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                store.requestAccess(to: .event) { granted, error in
                    if let error { cont.resume(throwing: error) }
                    else if !granted { cont.resume(throwing: CalendarSourceError.accessDenied) }
                    else { cont.resume() }
                }
            }
        }
    }
}

private extension CalendarEvent {
    init(ekEvent e: EKEvent) {
        self.init(
            id: e.calendarItemIdentifier,
            title: e.title ?? "",
            notes: e.notes,
            startDate: e.startDate,
            endDate: e.endDate,
            isAllDay: e.isAllDay,
            source: .apple
        )
    }
}
#endif
