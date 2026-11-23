import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers

public enum TempAppHandoffMode: String, CaseIterable, Identifiable, Sendable {
    case quit = "Quit App"
    case hide = "Hide App"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .quit: return "Quit"
        case .hide: return "Hide"
        }
    }
}

public enum AIBackend: String, CaseIterable, Identifiable, Sendable {
    case claudeCLI = "Claude CLI (Subscription)"
    case agyCLI = "Antigravity CLI (agy)"
    case opencodeCLI = "OpenCode CLI"
    case localRulesOnly = "Local Rules Only (Fast)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .claudeCLI: return "Claude CLI"
        case .agyCLI: return "agy"
        case .opencodeCLI: return "opencode"
        case .localRulesOnly: return "Local Rules"
        }
    }
}

public struct GuardrailEvent: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: String
    public let tag: String
    public let message: String
    public let tone: Tone

    public enum Tone: Sendable {
        case neutral, focus, warn, alert, success
    }
}

public struct InstalledAppOption: Identifiable, Hashable, Sendable {
    public let id: String // bundleIdentifier
    public let name: String
    public let path: String
}

@MainActor
@Observable
public final class FocusSessionStore {
    // Session config
    public var sessionActive: Bool = false
    public var goal: String = ""
    public var primaryAppName: String = "Claude"
    public var primaryAppBundleID: String = "com.anthropic.claudefordesktop"
    public var claudeCodeEnabled: Bool = true
    public var handoffMode: TempAppHandoffMode = .quit
    public var aiBackend: AIBackend = .claudeCLI
    public var aiVisionEnabled: Bool = false

    // Lock-In Countdown Timer (0 = Open-ended stopwatch; > 0 = Countdown sprint in minutes)
    public var targetDurationMinutes: Int = 25

    // Live runtime state
    public var activeAppName: String = "None"
    public var activeAppBundleID: String = ""
    public var activeWindowTitle: String = ""
    public var activeBrowserURL: String = ""

    public var tempAppName: String? = nil
    public var tempAppBundleID: String? = nil
    public var tempReason: String = ""

    public var pendingAppName: String? = nil
    public var pendingAppBundleID: String? = nil
    public var isApprovalModalVisible: Bool = false

    // Unstick Me & End-of-Session Recap state
    public var unstickMessage: String = ""
    public var isGeneratingUnstick: Bool = false

    public var recapGoal: String = ""
    public var recapDuration: String = "00:00"
    public var recapAlerts: Int = 0
    public var recapText: String = ""
    public var isGeneratingRecap: Bool = false
    public var isRecapVisible: Bool = false

    // Pebble mascot & Dynamic Island state
    public var faceState: PebbleState = .idle
    public var isIslandExpanded: Bool = false
    public var isLookingAround: Bool = false
    public var islandTitle: String = "Pebble is ready to lock in"
    public var islandSubtitle: String = "Click Pebble to start a focus session"
    public var islandShakeTrigger: Int = 0

    // Counters & logs
    public var secondsElapsed: Int = 0
    public var distractionAlerts: Int = 0
    public var eventLog: [GuardrailEvent] = [
        GuardrailEvent(
            timestamp: "00:00",
            tag: "READY",
            message: "Companion initialized. Set your focus goal and lock in.",
            tone: .neutral
        )
    ]

    // Distraction rules (editable in Settings)
    public var blockedDomains: [String] = [
        "x.com",
        "twitter.com",
        "reddit.com",
        "instagram.com",
        "tiktok.com",
        "facebook.com",
        "threads.net",
        "youtube.com"
    ]

    // Companion dev bundle IDs allowed when Claude Code CLI Loop is enabled
    public let claudeCodeCompanionBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.microsoft.VSCode",
        "com.t3code.app"
    ]

    // System apps never intercepted
    public let systemIgnoredBundleIDs: Set<String> = [
        "app.pebblefocus.companion",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.Spotlight",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.WindowManager",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.systempreferences"
    ]

    public var availableApps: [InstalledAppOption] = []

    // Internal timers / tasks
    private var sessionTimer: Timer?
    private var stateResetTask: Task<Void, Never>?
    private var warningCollapseTask: Task<Void, Never>?
    private var lookAroundTask: Task<Void, Never>?
    private var lastDistractionURL: String = ""
    private var lastDistractionTime: Date = .distantPast

    public var onStatusIconNeedsUpdate: (() -> Void)?
    public var onApprovalPanelVisibilityChanged: ((Bool) -> Void)?
    public var onStickyNoteVisibilityChanged: ((Bool) -> Void)?
    public var onDynamicIslandNeedsLayout: (() -> Void)?
    public var onRecapVisibilityChanged: ((Bool) -> Void)?

    public let aiJudge = CLIAIJudge()

    public init() {
        refreshInstalledApps()
        applyPebbleState(.idle, autoSettleToIdle: false)
    }

    public var isCountdownMode: Bool {
        targetDurationMinutes > 0
    }

    public var targetTotalSeconds: Int {
        max(0, targetDurationMinutes * 60)
    }

    public var secondsRemaining: Int {
        guard isCountdownMode else { return 0 }
        return max(0, targetTotalSeconds - secondsElapsed)
    }

    public var timerProgress: Double {
        guard isCountdownMode, targetTotalSeconds > 0 else { return 0 }
        return min(1.0, Double(secondsElapsed) / Double(targetTotalSeconds))
    }

    public var formattedDuration: String {
        let displaySeconds = (sessionActive && isCountdownMode) ? secondsRemaining : (isCountdownMode && !sessionActive ? targetTotalSeconds : secondsElapsed)
        let m = displaySeconds / 60
        let s = displaySeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    public var formattedElapsedDuration: String {
        let m = secondsElapsed / 60
        let s = secondsElapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    public func refreshInstalledApps() {
        var found: [InstalledAppOption] = []
        let appDirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities"
        ]
        let fm = FileManager.default

        for dir in appDirs {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let fullPath = (dir as NSString).appendingPathComponent(item)
                if let bundle = Bundle(path: fullPath),
                   let bundleID = bundle.bundleIdentifier {
                    let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                        ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                        ?? item.replacingOccurrences(of: ".app", with: "")
                    found.append(InstalledAppOption(id: bundleID, name: displayName, path: fullPath))
                }
            }
        }

        // Also include any currently running regular GUI apps (e.g., Homebrew / custom paths)
        for running in NSWorkspace.shared.runningApplications where running.activationPolicy == .regular {
            if let bundleID = running.bundleIdentifier,
               let url = running.bundleURL,
               let name = running.localizedName {
                found.append(InstalledAppOption(id: bundleID, name: name, path: url.path))
            }
        }

        // Deduplicate & sort with favorites first
        let unique = Dictionary(grouping: found, by: \.id).compactMap { $0.value.first }
        let priority = [
            "Claude", "Terminal", "Cursor", "Visual Studio Code", "Ghostty",
            "iTerm", "Warp", "Xcode", "T3 Code (Beta)", "Google Chrome", "Safari"
        ]
        availableApps = unique.sorted { a, b in
            let ia = priority.firstIndex(of: a.name) ?? Int.max
            let ib = priority.firstIndex(of: b.name) ?? Int.max
            if ia != ib { return ia < ib }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        // Keep current selection if still valid, otherwise default to Claude
        if !availableApps.contains(where: { $0.id == primaryAppBundleID }) {
            if let claude = availableApps.first(where: { $0.name.localizedCaseInsensitiveContains("Claude") }) {
                primaryAppName = claude.name
                primaryAppBundleID = claude.id
            } else if let first = availableApps.first {
                primaryAppName = first.name
                primaryAppBundleID = first.id
            }
        }
    }

    public func selectPrimaryApp(_ app: InstalledAppOption) {
        primaryAppBundleID = app.id
        primaryAppName = app.name
    }

    public func selectCustomPrimaryAppName(_ customName: String) {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let match = availableApps.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            selectPrimaryApp(match)
        } else {
            primaryAppName = trimmed
            primaryAppBundleID = "custom.\(trimmed.lowercased().replacingOccurrences(of: " ", with: "-"))"
        }
    }

    public func appIcon(for bundleID: String, path: String? = nil) -> NSImage {
        if let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        if let match = availableApps.first(where: { $0.id == bundleID }) {
            return NSWorkspace.shared.icon(forFile: match.path)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    // MARK: - Logging

    public func logEvent(_ tag: String, _ message: String, tone: GuardrailEvent.Tone = .neutral) {
        let entry = GuardrailEvent(
            timestamp: formattedDuration,
            tag: tag,
            message: message,
            tone: tone
        )
        eventLog.insert(entry, at: 0)
        if eventLog.count > 80 {
            eventLog.removeLast(eventLog.count - 80)
        }
    }

    public func clearLog() {
        eventLog.removeAll()
    }

    // MARK: - Pebble State Machine (mirrors HTML prototype)

    public func applyPebbleState(_ nextState: PebbleState, autoSettleToIdle: Bool = false) {
        faceState = nextState

        warningCollapseTask?.cancel()
        lookAroundTask?.cancel()
        stateResetTask?.cancel()
        isLookingAround = false

        if nextState == .idle {
            lookAroundTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled, let self, self.faceState == .idle else { return }
                self.isLookingAround = true
            }
        }

        isIslandExpanded = nextState.expandsIsland

        if nextState == .mad {
            islandShakeTrigger += 1
            // Show red warning banner for 5 seconds, then collapse back to floating red Pebble while still distracted
            warningCollapseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, let self, self.faceState == .mad else { return }
                self.isIslandExpanded = false
                self.onDynamicIslandNeedsLayout?()
            }
        }

        if autoSettleToIdle {
            let delayNs: UInt64 = switch nextState {
            case .happy: 1_400_000_000
            case .speaking: 1_800_000_000
            default: 1_200_000_000
            }
            stateResetTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delayNs)
                guard !Task.isCancelled, let self, self.faceState == nextState else { return }
                self.applyPebbleState(.idle, autoSettleToIdle: false)
                self.syncIdleSubtitle()
            }
        }

        onStatusIconNeedsUpdate?()
        onDynamicIslandNeedsLayout?()
    }

    public func triggerLookAround() {
        applyPebbleState(.idle, autoSettleToIdle: false)
        lookAroundTask?.cancel()
        isLookingAround = true
        logEvent("SCAN", "Pebble is looking around your screen and open tabs.", tone: .neutral)
    }

    private func syncIdleSubtitle() {
        if !sessionActive {
            islandTitle = "Pebble is ready to lock in"
            islandSubtitle = "Goal: \(goal)"
        } else if let temp = tempAppName {
            islandTitle = "In \(temp) (Approved)"
            islandSubtitle = "Sticky note: \(tempReason)"
        } else {
            islandTitle = "Locked in on \(primaryAppName)"
            islandSubtitle = goal
        }
    }

    // MARK: - Session Lifecycle

    public func startSession() {
        sessionActive = true
        secondsElapsed = 0
        distractionAlerts = 0
        unstickMessage = ""
        tempAppName = nil
        tempAppBundleID = nil
        tempReason = ""
        isApprovalModalVisible = false
        onStickyNoteVisibilityChanged?(false)
        onApprovalPanelVisibilityChanged?(false)

        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimerTick()
            }
        }

        islandTitle = isCountdownMode ? "Locked in • \(targetDurationMinutes)m sprint" : "Locked in on \(primaryAppName)"
        islandSubtitle = goal
        applyPebbleState(.speaking, autoSettleToIdle: true)
        logEvent("SESSION", "Locked in on \(primaryAppName) (\(isCountdownMode ? "\(targetDurationMinutes)m timer" : "open timer")): \"\(goal)\"", tone: .focus)

        // Bring primary app forward
        activateApp(bundleID: primaryAppBundleID)
    }

    private func handleTimerTick() {
        guard sessionActive else { return }
        secondsElapsed += 1
        if isCountdownMode && secondsRemaining == 0 {
            logEvent("TIMER", "\(targetDurationMinutes)m lock-in sprint completed!", tone: .success)
            endSessionWithRecap(completedTimer: true)
        }
    }

    public func stopSession() {
        endSessionWithRecap(completedTimer: false)
    }

    public func endSessionWithRecap(completedTimer: Bool = false) {
        let hadProgress = secondsElapsed > 0 || completedTimer
        let finalDuration = formattedElapsedDuration
        let finalGoal = goal
        let finalAlerts = distractionAlerts
        let recentEvents = eventLog.prefix(8).map { "[\($0.timestamp)] \($0.tag): \($0.message)" }.joined(separator: "\n")

        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionActive = false
        tempAppName = nil
        tempAppBundleID = nil
        tempReason = ""
        isApprovalModalVisible = false
        onStickyNoteVisibilityChanged?(false)
        onApprovalPanelVisibilityChanged?(false)

        if completedTimer {
            NSSound.beep()
            islandTitle = "Sprint Complete!"
            islandSubtitle = "Locked in for \(finalDuration) — nice work"
            applyPebbleState(.happy, autoSettleToIdle: true)
        } else {
            applyPebbleState(.idle, autoSettleToIdle: false)
            syncIdleSubtitle()
        }

        logEvent("RESET", "Focus session ended (\(finalDuration)).", tone: .neutral)

        guard hadProgress else { return }

        recapGoal = finalGoal
        recapDuration = finalDuration
        recapAlerts = finalAlerts
        recapText = ""
        isGeneratingRecap = true
        isRecapVisible = true
        onRecapVisibilityChanged?(true)

        let backend = aiBackend
        Task { [weak self] in
            guard let self else { return }
            let summary = await self.aiJudge.generateSessionRecap(
                backend: backend,
                goal: finalGoal,
                durationFormatted: finalDuration,
                distractionAlerts: finalAlerts,
                eventsSummary: recentEvents
            )
            self.recapText = summary
            self.isGeneratingRecap = false
        }
    }

    public func closeRecap() {
        isRecapVisible = false
        onRecapVisibilityChanged?(false)
    }

    public func requestUnstickCoaching() {
        guard !isGeneratingUnstick else { return }
        isGeneratingUnstick = true
        unstickMessage = ""

        islandTitle = "Pebble is thinking..."
        islandSubtitle = "Finding your fastest next move"
        applyPebbleState(.thinking, autoSettleToIdle: false)

        let backend = aiBackend
        let currentGoal = goal
        let currentApp = activeAppName == "None" ? primaryAppName : activeAppName
        let currentTitle = activeWindowTitle
        let currentURL = activeBrowserURL

        Task { [weak self] in
            guard let self else { return }
            let nudge = await self.aiJudge.generateUnstickNudge(
                backend: backend,
                goal: currentGoal,
                activeApp: currentApp,
                windowTitle: currentTitle,
                browserURL: currentURL
            )
            self.isGeneratingUnstick = false
            self.unstickMessage = nudge
            self.islandTitle = "Pebble Coaching Nudge"
            self.islandSubtitle = nudge
            self.applyPebbleState(.speaking, autoSettleToIdle: false)
            self.logEvent("COACH", nudge, tone: .focus)

            // Let the user read the nudge in the Dynamic Island for 7 seconds before settling
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            if self.faceState == .speaking {
                self.applyPebbleState(.idle, autoSettleToIdle: false)
                self.syncIdleSubtitle()
            }
        }
    }

    public func resetSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionActive = false
        secondsElapsed = 0
        distractionAlerts = 0
        unstickMessage = ""
        tempAppName = nil
        tempAppBundleID = nil
        tempReason = ""
        isApprovalModalVisible = false
        onStickyNoteVisibilityChanged?(false)
        onApprovalPanelVisibilityChanged?(false)
        applyPebbleState(.idle, autoSettleToIdle: false)
        syncIdleSubtitle()
        logEvent("RESET", "Session reset to standby.", tone: .neutral)
    }

    // MARK: - App Switch Guardrail

    public func handleAppActivated(name: String, bundleID: String) {
        activeAppName = name
        activeAppBundleID = bundleID

        guard sessionActive else { return }
        guard !bundleID.isEmpty else { return }

        // Never intercept system UI or Pebble itself
        if systemIgnoredBundleIDs.contains(bundleID) || bundleID == Bundle.main.bundleIdentifier {
            return
        }

        // Primary app -> clear mad state if returning from distraction
        if bundleID == primaryAppBundleID || name.localizedCaseInsensitiveCompare(primaryAppName) == .orderedSame {
            if faceState == .mad {
                islandTitle = "Back on \(primaryAppName)"
                islandSubtitle = goal
                applyPebbleState(.idle, autoSettleToIdle: false)
                logEvent("FOCUS", "Returned to primary app \(primaryAppName).", tone: .success)
            }
            return
        }

        // Claude Code CLI companion apps allowed when toggled on
        if claudeCodeEnabled && claudeCodeCompanionBundleIDs.contains(bundleID) {
            if faceState == .mad {
                applyPebbleState(.idle, autoSettleToIdle: false)
            }
            return
        }

        // Currently approved temporary app pass
        if let approvedID = tempAppBundleID, approvedID == bundleID {
            return
        }

        // Unapproved app! Ask why before allowing.
        requestAppApproval(appName: name, bundleID: bundleID)
    }

    public func requestAppApproval(appName: String, bundleID: String) {
        if !sessionActive {
            startSession()
        }
        pendingAppName = appName
        pendingAppBundleID = bundleID
        isApprovalModalVisible = true

        islandTitle = "Pebble is listening"
        islandSubtitle = "Why do you need to open \(appName)?"
        applyPebbleState(.listening, autoSettleToIdle: false)
        onApprovalPanelVisibilityChanged?(true)
        logEvent("GUARDRAIL", "Pebble listening for reason before opening \(appName).", tone: .warn)
    }

    public func cancelAppApproval() {
        let rejected = pendingAppName ?? "app"
        pendingAppName = nil
        pendingAppBundleID = nil
        isApprovalModalVisible = false
        onApprovalPanelVisibilityChanged?(false)

        applyPebbleState(.idle, autoSettleToIdle: false)
        syncIdleSubtitle()
        logEvent("STAYED", "Declined \(rejected) — stayed focused in \(primaryAppName).", tone: .focus)

        // Immediately bring primary app back to front
        activateApp(bundleID: primaryAppBundleID)
    }

    public func submitAppApproval(reason: String) {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let targetName = pendingAppName, let targetBundleID = pendingAppBundleID else { return }

        isApprovalModalVisible = false
        onApprovalPanelVisibilityChanged?(false)

        islandTitle = "Checking reason for \(targetName)..."
        islandSubtitle = trimmed
        applyPebbleState(.thinking, autoSettleToIdle: false)

        let currentGoal = goal
        let backend = aiBackend

        Task { [weak self] in
            guard let self else { return }
            let verdict = await self.aiJudge.evaluateAppReason(
                backend: backend,
                goal: currentGoal,
                targetApp: targetName,
                reason: trimmed
            )

            if verdict.approved {
                self.tempAppName = targetName
                self.tempAppBundleID = targetBundleID
                self.tempReason = trimmed
                self.pendingAppName = nil
                self.pendingAppBundleID = nil

                self.islandTitle = "Approved: \(targetName)"
                self.islandSubtitle = verdict.feedback.isEmpty ? trimmed : verdict.feedback
                self.applyPebbleState(.happy, autoSettleToIdle: true)
                self.onStickyNoteVisibilityChanged?(true)
                self.logEvent("APPROVED", "Opened \(targetName) with sticky note: \"\(trimmed)\"", tone: .focus)
                self.activateApp(bundleID: targetBundleID)
            } else {
                self.pendingAppName = nil
                self.pendingAppBundleID = nil
                self.distractionAlerts += 1
                self.islandTitle = "Hold up — off-task!"
                self.islandSubtitle = verdict.feedback.isEmpty ? "Doesn't match your current goal." : verdict.feedback
                self.applyPebbleState(.mad, autoSettleToIdle: false)
                self.logEvent("DENIED", "Pebble blocked \(targetName): \(verdict.feedback)", tone: .alert)
                self.activateApp(bundleID: self.primaryAppBundleID)
            }
        }
    }

    // MARK: - Complete Temporary Pass (Quit or Hide & Return)

    public func completeTempAppPass() {
        guard let finishedName = tempAppName, let finishedBundleID = tempAppBundleID else { return }

        let mode = handoffMode
        tempAppName = nil
        tempAppBundleID = nil
        tempReason = ""
        onStickyNoteVisibilityChanged?(false)

        // Execute Quit or Hide based on user's chosen mode
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: finishedBundleID).first {
            switch mode {
            case .quit:
                runningApp.terminate()
            case .hide:
                runningApp.hide()
            }
        }

        // Bring primary app back
        activateApp(bundleID: primaryAppBundleID)

        let verb = mode == .quit ? "Quit" : "Hid"
        islandTitle = "\(verb) \(finishedName) → Back on \(primaryAppName)"
        islandSubtitle = "Clean handoff! Resuming focus session."
        applyPebbleState(.happy, autoSettleToIdle: true)
        logEvent("COMPLETED", "Checked off sticky note, \(verb.lowercased()) \(finishedName), returned to \(primaryAppName).", tone: .success)
    }

    public func completeMilestone() {
        if tempAppName != nil {
            completeTempAppPass()
            return
        }
        islandTitle = "Milestone Completed!"
        islandSubtitle = "Great focus streak in \(primaryAppName)"
        applyPebbleState(.happy, autoSettleToIdle: true)
        logEvent("MILESTONE", "Completed milestone in \(primaryAppName).", tone: .success)
    }

    // MARK: - Browser Tab & Distraction Detection

    public func handleBrowserTabUpdate(url: String, title: String, appName: String) {
        activeBrowserURL = url
        if !title.isEmpty {
            activeWindowTitle = title
        }

        guard sessionActive else { return }
        guard !url.isEmpty else { return }

        let lowerURL = url.lowercased()
        let isBlocked = blockedDomains.contains { domain in
            let d = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !d.isEmpty else { return false }
            return lowerURL.contains(d)
        }

        if isBlocked {
            // Debounce identical distraction URL alerts to once per 12 seconds
            if url == lastDistractionURL && Date().timeIntervalSince(lastDistractionTime) < 12 {
                return
            }
            lastDistractionURL = url
            lastDistractionTime = Date()

            // If AI backend is active and user has a temp reason, let AI double-check YouTube/ambiguous tabs
            if lowerURL.contains("youtube.com") && aiBackend != .localRulesOnly && !tempReason.isEmpty {
                evaluateAmbiguousTabWithAI(url: url, title: title, appName: appName)
            } else {
                let host = URL(string: url)?.host ?? url
                triggerDistractionAlert(source: host, detail: title.isEmpty ? host : title)
            }
        } else if faceState == .mad {
            // User navigated away from the distracting tab
            lastDistractionURL = ""
            islandTitle = "Back on track"
            islandSubtitle = title.isEmpty ? (URL(string: url)?.host ?? appName) : title
            applyPebbleState(.idle, autoSettleToIdle: false)
            logEvent("TAB", "Navigated back to on-task tab: \(title.isEmpty ? url : title)", tone: .success)
        }
    }

    private func evaluateAmbiguousTabWithAI(url: String, title: String, appName: String) {
        islandTitle = "Checking if tab fits your goal..."
        islandSubtitle = title.isEmpty ? url : title
        applyPebbleState(.thinking, autoSettleToIdle: false)

        let currentGoal = goal
        let currentReason = tempReason
        let backend = aiBackend

        Task { [weak self] in
            guard let self else { return }
            let verdict = await self.aiJudge.evaluateBrowserTab(
                backend: backend,
                goal: currentGoal,
                tempReason: currentReason,
                url: url,
                title: title
            )
            if verdict.approved {
                self.islandTitle = "On-task tab verified"
                self.islandSubtitle = verdict.feedback.isEmpty ? title : verdict.feedback
                self.applyPebbleState(.idle, autoSettleToIdle: false)
                self.logEvent("VERIFIED", "AI approved tab \"\(title)\": \(verdict.feedback)", tone: .success)
            } else {
                let host = URL(string: url)?.host ?? url
                self.triggerDistractionAlert(source: host, detail: verdict.feedback.isEmpty ? title : verdict.feedback)
            }
        }
    }

    public func triggerDistractionAlert(source: String, detail: String) {
        distractionAlerts += 1
        islandTitle = "Tab Switch Distraction Detected!"
        islandSubtitle = "Off-task: \(detail) — return to \(primaryAppName)"
        applyPebbleState(.mad, autoSettleToIdle: false)
        logEvent("DISTRACTION", "Off-task tab \"\(source)\" (\(detail)). Pebble turned Mad red!", tone: .alert)
    }

    // MARK: - Helper

    public func activateApp(bundleID: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate(options: [.activateAllWindows])
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
