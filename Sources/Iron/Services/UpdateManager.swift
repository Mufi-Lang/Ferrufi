import Foundation
import AppKit

/// Lightweight description of an available update
public struct UpdateInfo: Codable, Sendable {
    public let version: String
    public let notes: String?
    public let url: URL?

    public init(version: String, notes: String? = nil, url: URL? = nil) {
        self.version = version
        self.notes = notes
        self.url = url
    }
}

/// Result of an update check
public enum UpdateCheckResult: Sendable {
    case noUpdate
    case updateAvailable(UpdateInfo)
    case error(Error)
}

/// Manages checking for updates and scheduling automatic checks.
///
/// Notes:
/// - This implementation attempts to fetch a small JSON feed describing the latest version.
///   The feed URL can be overridden by placing `"updateFeedURL"` in the app's configuration
///   `additionalSettings` (e.g. `configuration.additionalSettings["updateFeedURL"]`).
/// - If a real update feed is not configured or unreachable, the check will gracefully report
///   that no update was found (or an error if the network request failed).
@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var lastCheck: Date?
    @Published public private(set) var lastResult: UpdateCheckResult?

    private var autoTimer: Timer?
    /// Default interval for auto checks (24 hours)
    private let defaultInterval: TimeInterval = 60 * 60 * 24

    private init() {}

    /// Begins periodic automatic checks. If already running, the existing timer is replaced.
    /// - Parameter interval: The interval between checks in seconds (defaults to 24 hours).
    public func startAutoCheck(interval: TimeInterval? = nil) {
        stopAutoCheck()
        let interval = interval ?? defaultInterval

        // Fire immediately, then schedule repeating checks.
        Task { await self.performAutoCheck() }

        autoTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.performAutoCheck() }
        }
        RunLoop.main.add(autoTimer!, forMode: .common)
    }

    /// Stops periodic automatic checks.
    public func stopAutoCheck() {
        autoTimer?.invalidate()
        autoTimer = nil
    }

    private func performAutoCheck() async {
        _ = await checkForUpdates()
    }

    /// Performs an update check. This method is asynchronous and returns a `UpdateCheckResult`.
    /// Implementation:
    /// - If a feed URL is configured in `configuration.additionalSettings["updateFeedURL"]`, it will be used.
    /// - Otherwise a default placeholder URL is attempted (which will likely fail unless you provide one).
    /// - The JSON schema expected:
    ///   { "version": "1.2.3", "notes": "Changelog...", "url": "https://..." }
    public func checkForUpdates() async -> UpdateCheckResult {
        if isChecking {
            // Prevent parallel checks
            return lastResult ?? .noUpdate
        }
        isChecking = true
        defer {
            isChecking = false
            lastCheck = Date()
        }

        // Allow overriding the feed URL via app configuration if present
        let configuredFeed: String? = IronApp.shared?.configuration.additionalSettings["updateFeedURL"]
        let feedURLString = configuredFeed ?? "https://updates.iron.example/latest.json" // placeholder

        guard let feedURL = URL(string: feedURLString) else {
            let res: UpdateCheckResult = .noUpdate
            lastResult = res
            return res
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let res: UpdateCheckResult = .noUpdate
                lastResult = res
                return res
            }

            struct RemoteFeed: Decodable {
                let version: String
                let notes: String?
                let url: String?
            }

            let decoder = JSONDecoder()
            let feed = try decoder.decode(RemoteFeed.self, from: data)

            let remoteVersion = feed.version
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

            if isVersion(remoteVersion, greaterThan: currentVersion) {
                let info = UpdateInfo(version: remoteVersion, notes: feed.notes, url: URL(string: feed.url ?? ""))
                let res: UpdateCheckResult = .updateAvailable(info)
                lastResult = res
                return res
            }

            let res: UpdateCheckResult = .noUpdate
            lastResult = res
            return res
        } catch {
            let res: UpdateCheckResult = .error(error)
            lastResult = res
            return res
        }
    }

    /// Convenience that checks for updates and presents a user-facing alert with the outcome.
    /// This executes on the main actor (UI thread).
    public func checkForUpdatesAndNotify() {
        Task {
            let result = await checkForUpdates()
            await MainActor.run {
                switch result {
                case .noUpdate:
                    let alert = NSAlert()
                    alert.messageText = "No updates available"
                    alert.informativeText = "You're running the latest version."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                case .updateAvailable(let info):
                    let alert = NSAlert()
                    alert.messageText = "Update available — v\(info.version)"
                    alert.informativeText = info.notes ?? "A new version is available."
                    alert.alertStyle = .informational
                    if info.url != nil {
                        alert.addButton(withTitle: "Open Download Page")
                    }
                    alert.addButton(withTitle: "Dismiss")
                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn, let url = info.url {
                        NSWorkspace.shared.open(url)
                    }
                case .error(let err):
                    let alert = NSAlert(error: err)
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Helpers

    /// Compares two version strings like "1.2.3". Returns true if `v1` > `v2`.
    private func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let a = v1.split(separator: ".").map { Int($0) ?? 0 }
        let b = v2.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(a.count, b.count)
        for i in 0..<n {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
