import Foundation
import AppKit
import ScreenCaptureKit

/// Tier 4 Observation (Optional): On-demand active-window capture via ScreenCaptureKit.
/// Captures a single downscaled frame only when explicitly requested (never continuously recorded).
public final class ScreenCaptureService {
    public init() {}

    @available(macOS 14.0, *)
    public func captureFrontmostWindowImage() async -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let targetWindow = content.windows.first(where: {
                $0.owningApplication?.processID == frontPID && $0.isOnScreen && $0.frame.width > 120 && $0.frame.height > 120
            }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
            let config = SCStreamConfiguration()
            config.width = min(Int(targetWindow.frame.width), 1280)
            config.height = min(Int(targetWindow.frame.height), 800)
            config.scalesToFit = true
            config.showsCursor = false

            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            return nil
        }
    }
}
