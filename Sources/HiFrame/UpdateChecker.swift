import Foundation

struct AppVersion: Comparable {
    private let components: [Int]

    init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(parts.count), parts.allSatisfy({
            !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber }
        }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        components = numbers + Array(repeating: 0, count: 4 - numbers.count)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

struct UpdateRelease {
    let tagName: String

    var pageURL: URL {
        // Build the destination from the known repository, not a server-supplied URL.
        UpdateChecker.releasesURL.appendingPathComponent("tag").appendingPathComponent(tagName)
    }
}

final class UpdateChecker {
    nonisolated static let releasesURL = URL(string: "https://github.com/Nonex111/SteadyFrame/releases")!
    static let checkInterval: TimeInterval = 24 * 60 * 60
    private let defaults: UserDefaults
    private let fetch: () async throws -> (Data, URLResponse)
    private let now: () -> Date
    let currentVersion: String
    private(set) var isChecking = false

    enum Outcome {
        case available(UpdateRelease)
        case upToDate
    }

    init(
        currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        fetch: @escaping () async throws -> (Data, URLResponse) = UpdateChecker.fetchLatest
    ) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.now = now
        self.fetch = fetch
    }

    @MainActor func check(manual: Bool) async throws -> Outcome? {
        guard !isChecking else { return nil }
        let date = now()
        if !manual, let last = defaults.object(forKey: "updateLastAttempt") as? Date,
           date >= last, date.timeIntervalSince(last) < Self.checkInterval {
            return nil
        }
        guard let installed = AppVersion(currentVersion) else { throw UpdateError.invalidVersion }
        isChecking = true
        defer { isChecking = false }
        defaults.set(date, forKey: "updateLastAttempt")
        let (_, response) = try await fetch()
        guard let http = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
        guard http.statusCode == 200 else { throw UpdateError.http(http.statusCode) }
        // GitHub's /releases/latest redirects to the latest published stable tag.
        // Reject login pages, another repository, or an unexpected redirect destination.
        guard let url = http.url,
              url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              url.query == nil, url.fragment == nil,
              url.deletingLastPathComponent().path == Self.releasesURL.appendingPathComponent("tag").path,
              let latest = AppVersion(url.lastPathComponent) else { throw UpdateError.invalidResponse }
        let release = UpdateRelease(tagName: url.lastPathComponent)
        guard latest > installed else { return .upToDate }
        if !manual, defaults.string(forKey: "updateLastNotifiedVersion") == release.tagName {
            return nil
        }
        defaults.set(release.tagName, forKey: "updateLastNotifiedVersion")
        return .available(release)
    }

    nonisolated private static func fetchLatest() async throws -> (Data, URLResponse) {
        var request = URLRequest(
            url: releasesURL.appendingPathComponent("latest"),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 20
        )
        // HEAD follows the release redirect without downloading its HTML or using API quota.
        request.httpMethod = "HEAD"
        request.setValue("HiFrame-UpdateChecker", forHTTPHeaderField: "User-Agent")
        return try await URLSession.shared.data(for: request)
    }

    private enum UpdateError: LocalizedError {
        case invalidVersion, invalidResponse, http(Int)

        var errorDescription: String? {
            switch self {
            case .invalidVersion:
                return L10n.text("update.invalidVersion", fallback: "Could not read the app version. Open the packaged HiFrame.app.")
            case .invalidResponse:
                return L10n.text("update.invalidResponse", fallback: "GitHub returned unrecognized release information. Please try again later.")
            case .http(let code):
                if code == 403 || code == 429 {
                    return L10n.text("update.rateLimited", fallback: "GitHub refused the request or its rate limit was reached. Try again later or open the releases page.")
                }
                return L10n.format("update.httpError", fallback: "GitHub returned HTTP %d. Try again later or open the releases page.", code)
            }
        }
    }
}
