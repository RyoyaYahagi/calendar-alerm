#if canImport(UIKit)
import Foundation

struct ContactIssueService {
    // Cloudflare Worker をデプロイした後の URL に書き換えてください
    static let proxyURL = URL(string: "https://calendar-alarm-contact.yhgry.workers.dev")!

    enum Category: String, CaseIterable {
        case bug      = "bug"
        case feature  = "feature"
        case question = "question"
        case other    = "other"

        var label: String {
            switch self {
            case .bug:      return "バグ報告"
            case .feature:  return "機能要望"
            case .question: return "質問"
            case .other:    return "その他"
            }
        }
    }

    struct Response: Decodable {
        let number: Int
        let url: String
    }

    enum ServiceError: LocalizedError {
        case invalidResponse
        case serverError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:  return "サーバーから不正な応答が返りました。"
            case .serverError(let code): return "送信に失敗しました（コード: \(code)）。"
            }
        }
    }

    static func submit(
        category: Category,
        subject: String,
        email: String,
        message: String
    ) async throws -> Response {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "category": category.rawValue,
            "subject":  subject,
            "email":    email,
            "message":  message,
        ])

        let (data, urlResponse) = try await URLSession.shared.data(for: request)

        guard let http = urlResponse as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw ServiceError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}
#endif
