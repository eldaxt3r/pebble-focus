import SwiftUI

public struct MenuBarPopoverView: View {
    @Bindable var store: FocusSessionStore
    let permissions: PermissionsManager
    let onOpenSetup: () -> Void
    let onQuitApp: () -> Void

    @State private var isPrimaryHovered = false

    public init(
        store: FocusSessionStore,
        permissions: PermissionsManager,
        onOpenSetup: @escaping () -> Void,
        onQuitApp: @escaping () -> Void
    ) {
        self.store = store
        self.permissions = permissions
        self.onOpenSetup = onOpenSetup
        self.onQuitApp = onQuitApp
    }

    public var body: some View {
        ZStack {
            // Smoked Charcoal Matte Glass base matching reference card aesthetic
            LinearGradient(
                colors: [PebbleTheme.windowTop, PebbleTheme.windowBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            SubtleDotGridBackground(spacing: 14, dotOpacity: 0.035)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.06)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.9
                                    )
                            )
                        PebbleView(state: store.faceState, isLookingAround: false, size: 28)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Pebble")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Circle()
                                .fill(store.faceState == .mad ? Color(red: 210/255, green: 69/255, blue: 60/255) : (store.sessionActive ? Color(red: 53/255, green: 164/255, blue: 92/255) : Color.white.opacity(0.35)))
                                .frame(width: 6, height: 6)
                        }
                        Text(store.sessionActive ? "Locked in on \(store.primaryAppName)" : (store.isCountdownMode ? "\(store.targetDurationMinutes)m sprint ready" : "Ready to lock in"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.formattedDuration)
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.95))
                        if store.sessionActive && store.isCountdownMode {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.12))
                                    Capsule().fill(Color.white.opacity(0.85))
                                        .frame(width: geo.size.width * store.timerProgress)
                                }
                            }
                            .frame(width: 44, height: 2.5)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                    )
                }

                // Current Objective + Active Context
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CURRENT FOCUS OBJECTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.42))
                        Text(store.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Set your focus goal in Setup & Settings" : store.goal)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(store.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.45) : .white.opacity(0.95))
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.11), lineWidth: 0.8)
                    )

                    HStack(spacing: 8) {
                        // Allowed App tile with real macOS app logo
                        HStack(spacing: 8) {
                            Image(nsImage: store.appIcon(for: store.primaryAppBundleID))
                                .resizable()
                                .interpolation(.high)
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("ALLOWED APP")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .tracking(0.6)
                                    .foregroundStyle(.white.opacity(0.42))
                                Text(store.primaryAppName)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                        )

                        // Active Window tile
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ACTIVE WINDOW")
                                .font(.system(size: 8.5, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.42))
                            Text(store.activeAppName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
                        )
                    }
                }

                // Active Temporary Pass / Sticky Note inside Popover
                if let tempApp = store.tempAppName {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("📌 ACTIVE PASS: \(tempApp.uppercased())")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color(red: 120/255, green: 53/255, blue: 15/255))
                            Spacer()
                            Text(store.handoffMode.shortLabel)
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Color(red: 120/255, green: 53/255, blue: 15/255))
                        }
                        Text(store.tempReason)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Color(red: 69/255, green: 26/255, blue: 3/255))

                        Button {
                            store.completeTempAppPass()
                        } label: {
                            Label("Done — \(store.handoffMode.shortLabel) & return to \(store.primaryAppName)", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(red: 53/255, green: 164/255, blue: 92/255))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(red: 254/255, green: 240/255, blue: 138/255).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Primary & Secondary Monochrome Glass Actions
                VStack(spacing: 7) {
                    if store.sessionActive {
                        HStack(spacing: 7) {
                            glassActionButton(title: "Milestone", icon: "checkmark.circle") {
                                store.completeMilestone()
                            }
                            Button {
                                store.stopSession()
                            } label: {
                                Label("End Session", systemImage: "stop.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8.5)
                                    .background(Color.white.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            store.startSession()
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11.5, weight: .semibold))
                                Text("Lock In Focus Session")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9.5)
                            .background(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.96), Color(white: 0.86)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.9)
                            )
                            .shadow(color: Color.white.opacity(isPrimaryHovered ? 0.2 : 0.08), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .onHover { isPrimaryHovered = $0 }
                    }

                    HStack(spacing: 7) {
                        glassActionButton(title: "Setup & Settings", icon: "slider.horizontal.3") {
                            onOpenSetup()
                        }
                        glassActionButton(
                            title: store.isGeneratingUnstick ? "Thinking..." : "Unstick Me",
                            icon: "sparkles"
                        ) {
                            store.requestUnstickCoaching()
                        }
                        .disabled(store.isGeneratingUnstick)
                    }

                    if !store.unstickMessage.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.top, 2)
                            Text(store.unstickMessage)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button {
                                store.unstickMessage = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                    }
                }

                // Minimal Footer
                HStack {
                    Text("AI: \(store.aiBackend.shortName)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                    Spacer()
                    Button("Quit Pebble") {
                        onQuitApp()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .frame(width: 344)
        .fixedSize(horizontal: false, vertical: true)
        .preferredColorScheme(.dark)
    }

    private func glassActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7.5)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
    }
}
