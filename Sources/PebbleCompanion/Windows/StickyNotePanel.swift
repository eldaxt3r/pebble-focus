import SwiftUI
import AppKit

/// Draggable, always-on-top yellow Sticky Note panel shown whenever a temporary app pass is active.
@MainActor
public final class StickyNotePanelController {
    private let panel: NSPanel
    private let store: FocusSessionStore

    public init(store: FocusSessionStore) {
        self.store = store

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 175),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        self.panel = panel

        let hosting = NSHostingView(rootView: StickyNoteView(store: store))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
    }

    public func setVisible(_ visible: Bool) {
        if visible {
            positionTopRight()
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let x = visible.maxX - panel.frame.width - 20
        let y = visible.maxY - panel.frame.height - 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

private struct StickyNoteView: View {
    @Bindable var store: FocusSessionStore
    @State private var isHovered = false
    @State private var isChecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📌 APPROVED: \((store.tempAppName ?? "App").uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 120/255, green: 53/255, blue: 15/255))
                    .lineLimit(1)
                Spacer()
                Text("Active Pass")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 120/255, green: 53/255, blue: 15/255).opacity(0.12))
                    .foregroundStyle(Color(red: 120/255, green: 53/255, blue: 15/255))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            Text(store.tempReason)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 69/255, green: 26/255, blue: 3/255))
                .fixedSize(horizontal: false, vertical: true)

            // Quick Quit vs Hide toggle so user can try both right from the note
            HStack(spacing: 6) {
                Text("On done:")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color(red: 120/255, green: 53/255, blue: 15/255))
                Picker("", selection: $store.handoffMode) {
                    Text("Quit").tag(TempAppHandoffMode.quit)
                    Text("Hide").tag(TempAppHandoffMode.hide)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 110)
            }

            Divider()
                .overlay(Color(red: 120/255, green: 53/255, blue: 15/255).opacity(0.18))

            Button {
                isChecked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isChecked = false
                    store.completeTempAppPass()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isChecked ? Color(red: 53/255, green: 164/255, blue: 92/255) : Color(red: 120/255, green: 53/255, blue: 15/255))
                    Text("Done — \(store.handoffMode.shortLabel) & Return to \(store.primaryAppName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 69/255, green: 26/255, blue: 3/255))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 254/255, green: 240/255, blue: 138/255),
                    Color(red: 253/255, green: 224/255, blue: 71/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(red: 252/255, green: 211/255, blue: 77/255), lineWidth: 1.2)
        )
        .shadow(color: Color(red: 161/255, green: 98/255, blue: 7/255).opacity(0.28), radius: 14, x: 0, y: 8)
        .rotationEffect(.degrees(isHovered ? 0 : -1.2))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .padding(10)
    }
}
