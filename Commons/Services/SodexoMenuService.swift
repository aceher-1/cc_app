import Foundation

protocol MenuFetching {
    func fetch(dateKey: String, now: Date) async throws -> DayMenu
}

enum SourceError: LocalizedError {
    case configurationChanged, http(Int)
    var errorDescription: String? {
        switch self {
        case .configurationChanged: return "The dining website configuration changed. Please open the source menu while we update the integration."
        case .http(let code): return "The dining website could not return a menu (HTTP \(code)). Try again later."
        }
    }
}

struct SourceConfiguration: Codable {
    let locationID: String
    let menuID: String
    let publicClientKey: String
    let fetchedAt: Date
}

actor SodexoMenuService: MenuFetching {
    static let sourceURL = URL(string: "https://msoedining.sodexomyway.com/en-us/locations/the-dining-commons")!
    private let session: URLSession
    private let configurationURL: URL
    private var configuration: SourceConfiguration?
    private var discoveryTask: Task<SourceConfiguration, Error>?

    init(session: URLSession = .shared, directory: URL = DailyCache().directory) {
        self.session = session
        configurationURL = directory.appendingPathComponent("source-configuration.json")
        if let data = try? Data(contentsOf: configurationURL) {
            configuration = try? JSONDecoder().decode(SourceConfiguration.self, from: data)
        }
    }

    func fetch(dateKey: String, now: Date) async throws -> DayMenu {
        guard DiningDay.date(for: dateKey) != nil else { throw SourceError.configurationChanged }
        let config = try await discover(now: now)
        do { return try await menu(dateKey: dateKey, config: config, now: now) }
        catch SourceError.http(let code) where code == 401 || code == 403 {
            // A rotated public website client key gets exactly one rediscovery/retry.
            configuration = nil
            try? FileManager.default.removeItem(at: configurationURL)
            let refreshed = try await discover(now: now)
            return try await menu(dateKey: dateKey, config: refreshed, now: now)
        }
    }

    private func menu(dateKey: String, config: SourceConfiguration, now: Date) async throws -> DayMenu {
        var components = URLComponents(string: "https://api-prd.sodexomyway.net/v0.2/data/menu/\(config.locationID)/\(config.menuID)")!
        components.queryItems = [URLQueryItem(name: "date", value: dateKey)]
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(config.publicClientKey, forHTTPHeaderField: "API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await Self.load(request, session: session)
        return try MenuParser.parse(data, dateKey: dateKey, fetchedAt: now)
    }

    private func discover(now: Date) async throws -> SourceConfiguration {
        if let configuration, DiningDay.key(for: configuration.fetchedAt) == DiningDay.key(for: now) {
            return configuration
        }
        if let discoveryTask { return try await discoveryTask.value }
        let session = self.session
        let task = Task { try await Self.discoverSource(session: session, now: now) }
        discoveryTask = task
        defer { discoveryTask = nil }
        do {
            let result = try await task.value
            configuration = result
            // A persistence failure doesn't discard a usable menu request.
            try? FileManager.default.createDirectory(at: configurationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(result) { try? data.write(to: configurationURL, options: .atomic) }
            return result
        } catch {
            if let configuration { return configuration }
            throw error
        }
    }

    static func discoverSource(session: URLSession, now: Date) async throws -> SourceConfiguration {
        let htmlData = try await load(URLRequest(url: sourceURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30), session: session)
        guard let html = String(data: htmlData, encoding: .utf8),
              let location = capture(#""locationId"\s*:\s*"([0-9]+)""#, in: html),
              let menu = capture(#""menuId"\s*:\s*"([0-9]+)""#, in: html),
              let path = capture(#"src="(/static/js/main\.[a-zA-Z0-9]+\.js)""#, in: html),
              let scriptURL = URL(string: path, relativeTo: sourceURL)?.absoluteURL,
              scriptURL.host == sourceURL.host else { throw SourceError.configurationChanged }
        let scriptData = try await load(URLRequest(url: scriptURL, timeoutInterval: 30), session: session)
        guard let script = String(data: scriptData, encoding: .utf8),
              let production = capture(#"Production:\{(.{0,600})"#, in: script),
              let key = capture(#"API_KEY:"([a-zA-Z0-9-]+)""#, in: production) else { throw SourceError.configurationChanged }
        // Only the client key used by the public menu widget is read. No user login or private credentials.
        return SourceConfiguration(locationID: location, menuID: menu, publicClientKey: key, fetchedAt: now)
    }

    static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
    private static func load(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw SourceError.configurationChanged }
        guard (200..<300).contains(response.statusCode) else { throw SourceError.http(response.statusCode) }
        return data
    }
}
