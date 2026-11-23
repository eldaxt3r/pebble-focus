import Foundation
import AppKit

/// Tier 1 Observation: Instant, zero-polling app switch detection via NSWorkspace.
@MainActor
public final class AppWatcher {
    private weak var store: FocusSessionStore?
    private var observer: NSObjectProtocol?

    public init(store: FocusSessionStore) {
        self.store = store
    }

    public func start() {
        stop()

        if let front = NSWorkspace.shared.frontmostApplication {
            store?.activeAppName = front.localizedName ?? "Unknown"
            store?.activeAppBundleID = front.bundleIdentifier ?? ""
        }

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let name = app.localizedName ?? "Unknown App"
            let bundleID = app.bundleIdentifier ?? ""
            Task { @MainActor in
                self?.store?.handleAppActivated(name: name, bundleID: bundleID)
            }
        }
    }

    public func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
}
