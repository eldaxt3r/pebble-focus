import SwiftUI
import AppKit

/// Spotlight-style floating approval gate asking "Why do you need to open [App]?"
@MainActor
public final class AppApprovalPanelController {
    private let panel: NSPanel
    private let store: FocusSessionStore

    public init(store: FocusSessionStore) {
        self.store = store

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 310),
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

        let hosting = NSHostingView(rootView: AppApprovalModalView(store: store))
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

private struct AppApprovalModalView: View {
    let store: FocusSessionStore
    @State private var reasonText: String = ""
    @FocusState private var isInputFocused: Bool

    private let presets = [
        "Check documentation or reference",
        "Test local build & inspect logs",
        "Quick team message or PR review"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("APP GUARDRAIL CHECK")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.18))
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())

                    Text("Why do you need to open \(store.pendingAppName ?? "this app")?")
                        .font(.system(size: 17, weight: .bold))
                }
                Spacer()
                Button {
                    reasonText = ""
                    store.cancelAppApproval()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }

            Text("Your primary focus app is **\(store.primaryAppName)**. State a concrete reason to temporarily allow **\(store.pendingAppName ?? "this app")**. A sticky note will stay pinned until you check it off.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("CONCRETE REASON")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)

                TextField("e.g., Check docs or test local build", text: $reasonText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onSubmit {
                        submit()
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { preset in
                            Button(preset) {
                                reasonText = preset
                                isInputFocused = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            HStack {
                Text("Evaluator: \(store.aiBackend.shortName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Stay in \(store.primaryAppName)") {
                    reasonText = ""
                    store.cancelAppApproval()
                }
                .keyboardShortcut(.cancelAction)

                Button("Allow & Pin Sticky Note") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .disabled(reasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
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
        .onAppear {
            reasonText = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isInputFocused = true
            }
        }
        .onChange(of: store.pendingAppName) { _, _ in
            reasonText = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isInputFocused = true
            }
        }
    }

    private func submit() {
        let trimmed = reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        reasonText = ""
        store.submitAppApproval(reason: trimmed)
    }
}
