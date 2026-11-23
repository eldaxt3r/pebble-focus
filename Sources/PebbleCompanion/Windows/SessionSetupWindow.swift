import SwiftUI
import AppKit

@MainActor
public final class SessionSetupWindowController {
    private var window: NSWindow?
    private let store: FocusSessionStore
    private let permissions: PermissionsManager

    public init(store: FocusSessionStore, permissions: PermissionsManager) {
        self.store = store
        self.permissions = permissions
    }

    public func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 740),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "Pebble Companion"
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.appearance = NSAppearance(named: .darkAqua)
            win.isMovableByWindowBackground = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.isReleasedWhenClosed = false
            win.center()

            let hosting = NSHostingView(
                rootView: SessionSetupView(store: store, permissions: permissions) { [weak win] in
                    win?.close()
                }
            )
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            win.contentView = hosting
            self.window = win
        }

        store.refreshInstalledApps()
        permissions.refresh()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Premium Smoked Charcoal Liquid Glass Setup View

private struct SessionSetupView: View {
    @Bindable var store: FocusSessionStore
    let permissions: PermissionsManager
    let onClose: () -> Void

    @State private var appSearchText: String = ""
    @State private var isAppDropdownOpen: Bool = false
    @State private var newDomain: String = ""
    @State private var cliStatus: [AIBackend: String] = [:]
    @State private var isCTAHovered: Bool = false

    private var filteredApps: [InstalledAppOption] {
        let q = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return store.availableApps
        }
        return store.availableApps.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.id.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            // Smoked Charcoal Matte Glass backdrop
            LiquidGlassBackdrop()
                .ignoresSafeArea()

            LinearGradient(
                colors: [PebbleTheme.windowTop, PebbleTheme.windowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            SubtleDotGridBackground(spacing: 18, dotOpacity: 0.03)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Header
                    heroHeader

                    // 1. Focus Scope Card
                    glassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            sectionEyebrow("FOCUS SESSION", icon: "scope")

                            // Goal Input
                            VStack(alignment: .leading, spacing: 7) {
                                Text("What are you building right now?")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(.secondary)

                                TextField("What are you focusing on?", text: $store.goal)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(glassInputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(glassInputBorder)
                            }

                            // Searchable Primary Allowed App with Real Logos
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Primary Allowed App")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Search or type any app")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }

                                primaryAppPicker
                            }

                            // Lock-In Countdown Timer (Psychological Sprint Urgency)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Lock-In Timer")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(store.isCountdownMode ? "\(store.targetDurationMinutes) min countdown" : "Open-ended stopwatch")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }

                                lockInTimerPicker
                            }

                            // Sticky Note Handoff Mode (Quit vs Hide)
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Temporary App Handoff")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Action when you check off a sticky note")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                glassSegmentedControl
                            }

                            Divider()
                                .opacity(0.25)

                            // Claude Code CLI Toggle
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.primary.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Claude Code CLI Companion")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Allow Terminal, Ghostty, iTerm2, Warp, Cursor & VS Code alongside your main app")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Toggle("", isOn: $store.claudeCodeEnabled)
                                    .toggleStyle(.switch)
                                    .tint(.white.opacity(0.85))
                                    .labelsHidden()
                                    .controlSize(.small)
                            }

                            // Primary Monochrome Apple CTA
                            HStack(spacing: 10) {
                                Button {
                                    store.startSession()
                                    onClose()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: store.sessionActive ? "checkmark.shield.fill" : "lock.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(store.sessionActive ? "Update & Keep Focus Locked" : "Lock In Focus Session")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.96),
                                                Color(white: 0.86)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .shadow(color: Color.white.opacity(isCTAHovered ? 0.22 : 0.1), radius: isCTAHovered ? 14 : 8, x: 0, y: 4)
                                    .scaleEffect(isCTAHovered ? 1.008 : 1.0)
                                    .animation(.spring(response: 0.24, dampingFraction: 0.75), value: isCTAHovered)
                                }
                                .buttonStyle(.plain)
                                .onHover { isCTAHovered = $0 }

                                if store.sessionActive {
                                    Button {
                                        store.resetSession()
                                    } label: {
                                        Text("Reset")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.primary.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // 2. AI Guardrail Evaluator Card
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionEyebrow("AI GUARDRAIL EVALUATOR", icon: "sparkles")

                            VStack(spacing: 8) {
                                ForEach(AIBackend.allCases) { backend in
                                    aiBackendRow(backend)
                                }
                            }
                        }
                    }

                    // 3. Chrome Distraction Radar Card
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionEyebrow("CHROME DISTRACTION RADAR", icon: "safari")

                            HStack(spacing: 8) {
                                TextField("Add blocked domain (e.g., news.ycombinator.com)", text: $newDomain)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(glassInputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(glassInputBorder)
                                    .onSubmit { addDomain() }

                                Button {
                                    addDomain()
                                } label: {
                                    Text("Add")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(Color.primary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            WrappingFlowLayout(spacing: 8) {
                                ForEach(store.blockedDomains, id: \.self) { domain in
                                    HStack(spacing: 6) {
                                        Text(domain)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        Button {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                store.blockedDomains.removeAll { $0 == domain }
                                            }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.secondary)
                                                .padding(3)
                                                .background(Color.primary.opacity(0.08))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.leading, 10)
                                    .padding(.trailing, 6)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                                }
                            }
                        }
                    }

                    // 4. macOS Permissions Card
                    glassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionEyebrow("MACOS PERMISSIONS", icon: "hand.raised.fill")

                            permissionRow(
                                icon: "accessibility",
                                title: "Accessibility",
                                subtitle: "Reads active window titles across your Mac",
                                granted: permissions.accessibilityGranted,
                                actionLabel: permissions.accessibilityGranted ? "Granted" : "Grant",
                                action: { permissions.requestAccessibility() }
                            )

                            Divider().opacity(0.2)

                            permissionRow(
                                icon: "globe",
                                title: "Automation (Google Chrome)",
                                subtitle: "Reads active Chrome tab URL & title during sessions",
                                granted: nil,
                                actionLabel: "Open Settings",
                                action: { permissions.openAutomationSettings() }
                            )

                            Divider().opacity(0.2)

                            permissionRow(
                                icon: "rectangle.dashed.badge.record",
                                title: "Screen Recording (Optional)",
                                subtitle: "Used only if you enable ScreenCaptureKit visual checks",
                                granted: permissions.screenRecordingGranted,
                                actionLabel: permissions.screenRecordingGranted ? "Granted" : "Grant",
                                action: { permissions.requestScreenRecording() }
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
                .padding(.bottom, 28)
            }
        }
        .frame(width: 600, height: 740)
        .preferredColorScheme(.dark)
        .task {
            await checkCLIs()
            permissions.refresh()
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.38), .white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

                PebbleView(state: store.faceState, isLookingAround: false, size: 46)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Focus Companion")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Define Your Focus Scope")
                    .font(.system(size: 23, weight: .bold, design: .rounded))

                Text("Pebble floats above your workspace and keeps you aligned on one goal.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Searchable Primary App Picker with Real Logos

    private var primaryAppPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected app display + search trigger
            HStack(spacing: 10) {
                Image(nsImage: store.appIcon(for: store.primaryAppBundleID))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                TextField("Search or type app name (e.g. Terminal, Claude)...", text: $appSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .medium))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            isAppDropdownOpen = true
                        }
                    }
                    .onChange(of: appSearchText) { _, newValue in
                        if !newValue.isEmpty && !isAppDropdownOpen {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                isAppDropdownOpen = true
                            }
                        }
                    }
                    .onSubmit {
                        if let first = filteredApps.first {
                            store.selectPrimaryApp(first)
                        } else if !appSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                            store.selectCustomPrimaryAppName(appSearchText)
                        }
                        appSearchText = ""
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            isAppDropdownOpen = false
                        }
                    }

                if !appSearchText.isEmpty {
                    Button {
                        appSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Current active monochrome pill badge
                Text(store.primaryAppName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    )

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isAppDropdownOpen.toggle()
                    }
                } label: {
                    Image(systemName: isAppDropdownOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(glassInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(glassInputBorder)

            // Expandable Liquid Glass App List with Real Logos
            if isAppDropdownOpen {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(filteredApps) { app in
                                let isSelected = app.id == store.primaryAppBundleID
                                Button {
                                    store.selectPrimaryApp(app)
                                    appSearchText = ""
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        isAppDropdownOpen = false
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(nsImage: store.appIcon(for: app.id, path: app.path))
                                            .resizable()
                                            .interpolation(.high)
                                            .frame(width: 24, height: 24)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(app.name)
                                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                                .foregroundStyle(.primary)
                                            Text(app.id)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? Color.white.opacity(0.12) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }

                            // Allow custom typed app if not found in installed list
                            let trimmed = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !filteredApps.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
                                Button {
                                    store.selectCustomPrimaryAppName(trimmed)
                                    appSearchText = ""
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                        isAppDropdownOpen = false
                                    }
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "plus.app.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white)
                                            .frame(width: 24, height: 24)
                                        Text("Use custom app \"\(trimmed)\"")
                                            .font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 210)
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Lock-In Timer Picker

    private var lockInTimerPicker: some View {
        let presets: [(String, Int)] = [
            ("15m", 15),
            ("25m", 25),
            ("45m", 45),
            ("60m", 60),
            ("∞ Open", 0)
        ]

        return HStack(spacing: 6) {
            ForEach(presets, id: \.1) { label, mins in
                let selected = store.targetDurationMinutes == mins
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.8)) {
                        store.targetDurationMinutes = mins
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: selected ? .bold : .medium, design: .monospaced))
                        .foregroundStyle(selected ? .black : .white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? Color.white.opacity(0.94) : Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? Color.white : Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }

            // Custom minutes field
            HStack(spacing: 3) {
                TextField("min", value: $store.targetDurationMinutes, format: .number)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 34)
                Text("m")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(glassInputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(glassInputBorder)
        }
    }

    // MARK: - Glass Segmented Control (Quit vs Hide)

    private var glassSegmentedControl: some View {
        HStack(spacing: 3) {
            ForEach(TempAppHandoffMode.allCases) { mode in
                let selected = store.handoffMode == mode
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                        store.handoffMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Group {
                                if selected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.primary.opacity(0.14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                                        )
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    // MARK: - AI Backend Glass Selector Row

    private func aiBackendRow(_ backend: AIBackend) -> some View {
        let selected = store.aiBackend == backend
        let path = cliStatus[backend]
        let isLocalOnly = backend == .localRulesOnly

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                store.aiBackend = backend
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: backendIcon(backend))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? .black : .secondary)
                    .frame(width: 30, height: 30)
                    .background(selected ? Color.white : Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(backend.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if isLocalOnly {
                        Text("Zero latency, offline domain & rule engine")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(path != nil ? Color(red: 53/255, green: 164/255, blue: 92/255) : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(path ?? "Not found in PATH")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Color.white : Color.secondary.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(selected ? Color.white.opacity(0.11) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(
                        selected ? Color.white.opacity(0.36) : Color.white.opacity(0.09),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func backendIcon(_ backend: AIBackend) -> String {
        switch backend {
        case .claudeCLI: return "sparkle"
        case .agyCLI: return "wand.and.stars"
        case .opencodeCLI: return "chevron.left.forwardslash.chevron.right"
        case .localRulesOnly: return "bolt.shield.fill"
        }
    }

    // MARK: - Shared Smoked Charcoal Card & Helpers

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        SmokedGlassCard(cornerRadius: 20, padding: 18, showDots: true) {
            content()
        }
    }

    private func sectionEyebrow(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(PebbleTheme.textSecondary)
            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(PebbleTheme.textSecondary)
        }
    }

    private var glassInputBackground: some View {
        PebbleTheme.wellBackground
    }

    private var glassInputBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(PebbleTheme.innerRimGradient, lineWidth: 0.9)
    }

    @ViewBuilder
    private func permissionRow(
        icon: String,
        title: String,
        subtitle: String,
        granted: Bool?,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(granted == true ? Color(red: 53/255, green: 164/255, blue: 92/255) : .secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: action) {
                HStack(spacing: 5) {
                    if granted == true {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(actionLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    granted == true
                        ? Color(red: 53/255, green: 164/255, blue: 92/255).opacity(0.18)
                        : Color.primary.opacity(0.09)
                )
                .foregroundStyle(granted == true ? Color(red: 53/255, green: 164/255, blue: 92/255) : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .disabled(granted == true)
        }
    }

    private func addDomain() {
        let cleaned = newDomain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        guard !cleaned.isEmpty else { return }
        if !store.blockedDomains.contains(cleaned) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                store.blockedDomains.append(cleaned)
            }
        }
        newDomain = ""
    }

    private func checkCLIs() async {
        for backend in [AIBackend.claudeCLI, .agyCLI, .opencodeCLI] {
            if let path = await store.aiJudge.resolveCLIPath(for: backend) {
                cliStatus[backend] = path
            }
        }
    }
}

// MARK: - Non-Truncating Wrapping Flow Layout for Domain Chips

private struct WrappingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 500
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
