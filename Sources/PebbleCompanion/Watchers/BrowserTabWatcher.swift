import Foundation
import AppKit
import ApplicationServices

/// Tier 2 & 3 Observation:
/// - Reads active window title via Accessibility API (AXUIElement) when granted.
/// - Reads active Google Chrome (plus Safari/Arc/Brave) tab URL & title via AppleScript ONLY when a browser is frontmost.
@MainActor
public final class BrowserTabWatcher {
    private weak var store: FocusSessionStore?
    private var pollTimer: Timer?

    private let supportedBrowserBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.apple.Safari"
    ]

    public init(store: FocusSessionStore) {
        self.store = store
    }

    public func start() {
        stop()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        guard let store, let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = frontApp.bundleIdentifier ?? ""
        let appName = frontApp.localizedName ?? ""

        // Read frontmost window title via Accessibility if granted
        if AXIsProcessTrusted(), let title = readFrontWindowTitle(pid: frontApp.processIdentifier), !title.isEmpty {
            store.activeWindowTitle = title
        }

        // Only query browser tab URL when a supported browser is frontmost and session is active
        guard store.sessionActive, supportedBrowserBundleIDs.contains(bundleID) else { return }

        Task.detached(priority: .utility) {
            guard let tabInfo = Self.fetchBrowserTab(bundleID: bundleID) else { return }
            await MainActor.run {
                store.handleBrowserTabUpdate(url: tabInfo.url, title: tabInfo.title, appName: appName)
            }
        }
    }

    private func readFrontWindowTitle(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let winStatus = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard winStatus == .success, let windowObj = focusedWindow else { return nil }

        let windowElement = windowObj as! AXUIElement
        var titleValue: CFTypeRef?
        let titleStatus = AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue)
        guard titleStatus == .success, let title = titleValue as? String else { return nil }
        return title
    }

    private nonisolated static func fetchBrowserTab(bundleID: String) -> (url: String, title: String)? {
        let scriptSource: String
        switch bundleID {
        case "com.google.Chrome":
            scriptSource = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    set t to active tab of front window
                    return (URL of t) & "|||" & (title of t)
                end if
            end tell
            """
        case "com.google.Chrome.canary":
            scriptSource = """
            tell application "Google Chrome Canary"
                if (count of windows) > 0 then
                    set t to active tab of front window
                    return (URL of t) & "|||" & (title of t)
                end if
            end tell
            """
        case "company.thebrowser.Browser":
            scriptSource = """
            tell application "Arc"
                if (count of windows) > 0 then
                    set t to active tab of front window
                    return (URL of t) & "|||" & (title of t)
                end if
            end tell
            """
        case "com.brave.Browser":
            scriptSource = """
            tell application "Brave Browser"
                if (count of windows) > 0 then
                    set t to active tab of front window
                    return (URL of t) & "|||" & (title of t)
                end if
            end tell
            """
        case "com.apple.Safari":
            scriptSource = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set t to current tab of front window
                    return (URL of t) & "|||" & (name of t)
                end if
            end tell
            """
        default:
            return nil
        }

        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource),
              let result = script.executeAndReturnError(&errorInfo).stringValue else {
            return nil
        }

        let parts = result.components(separatedBy: "|||")
        let url = parts.first ?? ""
        let title = parts.count > 1 ? parts[1] : ""
        return (url, title)
    }
}
