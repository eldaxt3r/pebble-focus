import SwiftUI
import AppKit

/// Monochrome Dark Liquid Glass End-of-Session Recap Panel powered by the user's selected CLI subscription.
@MainActor
public final class SessionRecapPanelController {
    private let panel: NSPanel
    private let store: FocusSessionStore

    public init(store: FocusSessionStore) {
        self.store = store

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.level = .floating
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        self.panel = panel

        let hosting = NSHostingView(rootView: SessionRecapView(store: store))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
    }

    public func setVisible(_ visible: Bool) {
        if visible {
            centerUpperScreen()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    private func centerUpperScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - (panel.frame.width / 2.0)
        let y = visible.maxY - panel.frame.height - 110
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct SessionRecapView: View {
    let store: FocusSessionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    PebbleView(state: store.isGeneratingRecap ? .thinking : .happy, isLookingAround: false, size: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("FOCUS SPRINT RECAP")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(store.recapGoal)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    store.closeRecap()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Metrics Strip
            HStack(spacing: 10) {
                metricTile(label: "TIME FOCUSED", value: store.recapDuration, icon: "timer")
                metricTile(label: "ALERTS", value: "\(store.recapAlerts)", icon: "shield.checkered")
                metricTile(label: "EVALUATOR", value: store.aiBackend.shortName, icon: "sparkles")
            }

            // AI Recap Box
            VStack(alignment: .leading, spacing: 6) {
                Text("PEBBLE SUMMARY & NEXT STEP")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.45))

                if store.isGeneratingRecap {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Summarizing your sprint with \(store.aiBackend.shortName)...")
                            .font(.system(size: 12.5))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.vertical, 8)
                } else {
                    Text(store.recapText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            )

            // Actions
            HStack(spacing: 10) {
                Button {
                    store.closeRecap()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    store.closeRecap()
                    store.startSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start Another Sprint")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(width: 440)
        .background {
            ZStack {
                LinearGradient(
                    colors: [PebbleTheme.cardTop, PebbleTheme.cardBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                SubtleDotGridBackground(spacing: 14, dotOpacity: 0.035)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(PebbleTheme.rimGradient, lineWidth: 1)
        )
        .preferredColorScheme(.dark)
    }

    private func metricTile(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        )
    }
}
