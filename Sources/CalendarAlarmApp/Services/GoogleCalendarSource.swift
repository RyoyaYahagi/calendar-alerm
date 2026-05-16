#if canImport(UIKit)
import Foundation
import CalendarAlarmCore

struct GoogleCalendarSource: CalendarSource {
    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func fetchEvents(from start: Date, to end: Date) async throws -> [CalendarEvent] {
        let iso = ISO8601DateFormatter()
        var comps = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
        comps.queryItems = [
            URLQueryItem(name: "timeMin",      value: iso.string(from: start)),
            URLQueryItem(name: "timeMax",      value: iso.string(from: end)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "maxResults",   value: "250"),
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GoogleCalendarError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(GoogleEventList.self, from: data)
            .items
            .compactMap(CalendarEvent.init(googleItem:))
    }
}

// MARK: - Decodable response types

private struct GoogleEventList: Decodable {
    let items: [GoogleEventItem]
}

private struct GoogleEventItem: Decodable {
    let id: String
    let summary: String?
    let description: String?
    let start: GoogleDateTime
    let end: GoogleDateTime
}

private struct GoogleDateTime: Decodable {
    let dateTime: String?
    let date: String?
}

private extension CalendarEvent {
    init?(googleItem item: GoogleEventItem) {
        let iso = ISO8601DateFormatter()
        let dateOnly: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }()
        let isAllDay = item.start.dateTime == nil
        guard
            let startDate = item.start.dateTime.flatMap(iso.date(from:))
                         ?? item.start.date.flatMap(dateOnly.date(from:)),
            let endDate   = item.end.dateTime.flatMap(iso.date(from:))
                         ?? item.end.date.flatMap(dateOnly.date(from:))
        else { return nil }

        self.init(
            id: item.id,
            title: item.summary ?? "(no title)",
            notes: item.description,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            source: .google
        )
    }
}

enum GoogleCalendarError: Error, LocalizedError {
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): "Google Calendar API エラー: HTTP \(code)"
        }
    }
}
#endif
