import Foundation

protocol MenuFetching {
    func fetch(dateKey: String, now: Date) async throws -> DayMenu
}

enum SharedFeedError: LocalizedError {
    case unavailable(Int), changedFormat
    var errorDescription: String? {
        switch self {
        case .unavailable(let code): return "The shared menu service is unavailable (HTTP \(code)). Try again later or open the original menu."
        case .changedFormat: return "The shared menu service returned an unfamiliar format. Open the original menu or try again later."
        }
    }
}

struct SharedMenuService: MenuFetching {
    static let sourceURL = URL(string: "https://msoedining.sodexomyway.com/en-us/locations/the-dining-commons")!
    static let defaultBaseURL = URL(string: "https://aceher-1.github.io/cc_app/api/")!
    let session: URLSession
    let baseURL: URL
    init(session: URLSession = .shared, baseURL: URL = SharedMenuService.defaultBaseURL) {
        self.session = session
        self.baseURL = baseURL
    }
    func fetch(dateKey: String, now: Date) async throws -> DayMenu {
        guard DiningDay.date(for: dateKey) != nil else { throw SharedFeedError.changedFormat }
        let url = baseURL.appendingPathComponent("\(dateKey).json")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw SharedFeedError.changedFormat }
        guard (200..<300).contains(response.statusCode) else { throw SharedFeedError.unavailable(response.statusCode) }
        return try Self.decode(data, dateKey: dateKey, checkedAt: now)
    }

    static func decode(_ data: Data, dateKey: String, checkedAt: Date) throws -> DayMenu {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              envelope["schemaVersion"] as? Int == 1,
              envelope["date"] as? String == dateKey,
              let timestamp = envelope["updatedAt"] as? String,
              let updatedAt = ISO8601DateFormatter().date(from: timestamp),
              updatedAt <= checkedAt.addingTimeInterval(300),
              let meals = envelope["meals"] as? [[String: Any]] else { throw SharedFeedError.changedFormat }
        let parsed = try MenuParser.parse(JSONSerialization.data(withJSONObject: meals), dateKey: dateKey, fetchedAt: updatedAt)
        // checkedAt controls client downloads; fetchedAt is the source timestamp shown to users.
        return DayMenu(dateKey: parsed.dateKey, fetchedAt: parsed.fetchedAt, meals: parsed.meals, checkedAt: checkedAt)
    }
}
