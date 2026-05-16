#if canImport(UIKit)
import Foundation
import CalendarAlarmCore

protocol CalendarSource: Sendable {
    func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarEvent]
}

enum CalendarSourceError: Error, LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: "カレンダーへのアクセスが拒否されました"
        }
    }
}
#endif
