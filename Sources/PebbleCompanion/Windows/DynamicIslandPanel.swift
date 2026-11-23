import SwiftUI
import AppKit

/// Borderless, transparent, non-activating floating Dynamic Island panel at top-center of screen.
@MainActor
public final class DynamicIslandPanelController {
    private let panel: NSPanel
    private let store: FocusSessionStore
    private let onPebbleTapped: () -> Void

    public init(store: FocusSessionStore, onPebbleTapped: @escaping () -> Void) {
        self.store = store
        self.onPebbleTapped = onPebbleTapped

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.becomesKeyOnlyIfNeeded = true

        self.panel = panel

        let rootView = DynamicIslandView(store: store, onTap: onPebbleTapped)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView

        reposition()
    }

    public func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    public func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = store.isIslandExpanded ? 410 : 84
        let height: CGFloat = 72
        let x = visible.midX - (width / 2.0)
        // Float cleanly just below the menu bar (and below any notch)
        let y = visible.maxY - height - 4
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: false)
    }
}

private struct DynamicIslandView: View {
    let store: FocusSessionStore
    let onTap: () -> Void

    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            PebbleView(
                state: store.faceState,
                isLookingAround: store.isLookingAround,
                size: 48
            )
            .frame(width: 48, height: 48)

            if store.isIslandExpanded {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.faceState.dotColor)
                                .frame(width: 7, height: 7)
                            Text(store.islandTitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        Text(store.islandSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 220, alignment: .leading)

                    Text(store.faceState.displayTag.uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(tagBackground)
                        .foregroundStyle(tagForeground)
                        .clipShape(Capsule())
                }
                .padding(.trailing, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))
            }
        }
        .padding(.horizontal, store.isIslandExpanded ? 14 : 6)
        .padding(.vertical, store.isIslandExpanded ? 8 : 4)
        .background {
            if store.isIslandExpanded {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(store.faceState == .mad ? Color(red: 254/255, green: 226/255, blue: 226/255).opacity(0.65) : Color.white.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                store.faceState == .mad
                                    ? Color(red: 210/255, green: 69/255, blue: 60/255).opacity(0.55)
                                    : Color.primary.opacity(0.12),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: store.faceState == .mad
                            ? Color(red: 210/255, green: 69/255, blue: 60/255).opacity(0.32)
                            : Color.black.opacity(0.18),
                        radius: 14,
                        x: 0,
                        y: 6
                    )
            }
        }
        .offset(x: shakeOffset)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: store.isIslandExpanded)
        .onChange(of: store.islandShakeTrigger) { _, _ in
            performIslandShake()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var tagBackground: Color {
        switch store.faceState {
        case .mad: return Color(red: 210/255, green: 69/255, blue: 60/255).opacity(0.22)
        case .happy: return Color(red: 53/255, green: 164/255, blue: 92/255).opacity(0.22)
        case .listening: return Color.orange.opacity(0.22)
        case .thinking: return Color.cyan.opacity(0.22)
        case .speaking: return Color.indigo.opacity(0.22)
        case .idle: return Color.primary.opacity(0.1)
        }
    }

    private var tagForeground: Color {
        switch store.faceState {
        case .mad: return Color(red: 153/255, green: 27/255, blue: 27/255)
        case .happy: return Color(red: 20/255, green: 83/255, blue: 45/255)
        case .listening: return Color.orange
        case .thinking: return Color.blue
        case .speaking: return Color.indigo
        case .idle: return .primary
        }
    }

    private func performIslandShake() {
        let offsets: [(Double, CGFloat)] = [
            (0.0, -4), (0.07, 4), (0.14, -4), (0.21, 3), (0.28, -2), (0.35, 0)
        ]
        for (delay, dx) in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.06)) {
                    shakeOffset = dx
                }
            }
        }
    }
}
