import AppKit
import Foundation
import Observation

/// Checks the Pebble website for a newer release.
///
/// The site publishes `version.json` (written by `make-release.sh`):
/// `{"version": "1.0.1", "build": 2, "url": "https://…/Pebble.dmg", "notes": "…"}`
/// When its version is newer than this app's, Pebble shows an "Update available" banner
/// in the menu bar popover and asks once per new version.
@MainActor
@Observable
public final class UpdateChecker {
    public struct Release: Decodable, Equatable {
        public let version: String
        public let url: String
        public let notes: String?
    }

    public enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case failed
    }

    public static let feedURL = URL(string: "https://pebble-focus.vercel.app/version.json")!
    private static let allowedDownloadHosts: Set<String> = ["pebble-focus.vercel.app", "github.com"]
    private static let promptedVersionKey = "pebble.update.promptedVersion"
    private static let recheckInterval: TimeInterval = 6 * 60 * 60

    public private(set) var status: Status = .idle
    public let currentVersion: String

    private var timer: Timer?

    public init(bundle: Bundle = .main) {
        currentVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    public var availableRelease: Release? {
        if case let .available(release) = status { return release }
        return nil
    }

    /// Checks shortly after launch, then every few hours while Pebble runs.
    public func start() {
        Task { await check(userInitiated: false) }
        timer = Timer.scheduledTimer(withTimeInterval: Self.recheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check(userInitiated: false) }
        }
    }

    public func check(userInitiated: Bool) async {
        if status == .checking { return }
        status = .checking
        do {
            var request = URLRequest(url: Self.feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
            request.setValue("Pebble/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let release = try JSONDecoder().decode(Release.self, from: data)

            if Self.isVersion(release.version, newerThan: currentVersion), downloadURL(for: release) != nil {
                status = .available(release)
                promptIfNeeded(release, force: userInitiated)
            } else {
                status = .upToDate
                if userInitiated { showUpToDateAlert() }
            }
        } catch {
            status = .failed
            if userInitiated { showFailedAlert() }
        }
    }

    public func openDownload() {
        guard let release = availableRelease, let url = downloadURL(for: release) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Helpers

    private func downloadURL(for release: Release) -> URL? {
        guard let url = URL(string: release.url),
              url.scheme == "https",
              let host = url.host, Self.allowedDownloadHosts.contains(host) else { return nil }
        return url
    }

    /// Compares dotted versions numerically: 1.0.10 > 1.0.9, 1.1 > 1.0.5.
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func promptIfNeeded(_ release: Release, force: Bool) {
        let defaults = UserDefaults.standard
        if !force, defaults.string(forKey: Self.promptedVersionKey) == release.version { return }
        defaults.set(release.version, forKey: Self.promptedVersionKey)

        let alert = NSAlert()
        alert.messageText = "Pebble \(release.version) is available"
        var info = "You have version \(currentVersion)."
        if let notes = release.notes, !notes.isEmpty { info += "\n\n\(notes)" }
        info += "\n\nDownload the new Pebble.dmg, quit Pebble, then drag the new Pebble into Applications and replace the old one."
        alert.informativeText = info
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openDownload()
        }
    }

    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = "Pebble is up to date"
        alert.informativeText = "You have the latest version (\(currentVersion))."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showFailedAlert() {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "Check your internet connection and try again."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
