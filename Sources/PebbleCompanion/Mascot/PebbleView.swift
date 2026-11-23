import SwiftUI

public struct PebbleView: View {
    public let state: PebbleState
    public let isLookingAround: Bool
    public let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breatheToggle = false
    @State private var swayToggle = false
    @State private var speechToggle = false
    @State private var isBlinking = false
    @State private var lookOffset: CGSize = .zero
    @State private var lookScale: CGFloat = 1.0
    @State private var oneShotScaleX: CGFloat = 1.0
    @State private var oneShotScaleY: CGFloat = 1.0
    @State private var oneShotOffsetX: CGFloat = 0
    @State private var oneShotOffsetY: CGFloat = 0
    @State private var animationToken = UUID()

    public init(state: PebbleState, isLookingAround: Bool = false, size: CGFloat = 48) {
        self.state = state
        self.isLookingAround = isLookingAround
        self.size = size
    }

    private var s: CGFloat { size / 100.0 }

    public var body: some View {
        ZStack {
            // Pebble body + stroke
            PebbleBodyShape()
                .fill(state.bodyColor)
                .overlay(
                    PebbleBodyShape()
                        .stroke(state.strokeColor, lineWidth: max(1.0, 1.45 * s))
                )

            // Eyes layer
            eyesView
                .scaleEffect(eyeBaseScale * lookScale)
                .offset(
                    x: (eyeBaseOffset.width + lookOffset.width) * s,
                    y: (eyeBaseOffset.height + lookOffset.height) * s
                )
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72), value: state)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: lookOffset)
        }
        .frame(width: size, height: size)
        .scaleEffect(x: bodyScaleX, y: bodyScaleY)
        .offset(x: bodyOffsetX * s, y: bodyOffsetY * s)
        .rotationEffect(.degrees(bodyRotation))
        .shadow(color: Color.black.opacity(0.24), radius: 7 * s, x: 0, y: 4 * s)
        .onAppear {
            startStateAnimations()
        }
        .onChange(of: state) { _, _ in
            startStateAnimations()
        }
        .onChange(of: isLookingAround) { _, looking in
            if looking && state == .idle && !reduceMotion {
                startLookAroundLoop()
            } else {
                lookOffset = .zero
                lookScale = 1.0
            }
        }
        .accessibilityLabel("Pebble focus companion, \(state.rawValue)")
    }

    // MARK: - Eyes

    @ViewBuilder
    private var eyesView: some View {
        ZStack {
            // Neutral / Idle / Listening / Thinking / Speaking eyes
            if state == .idle || state == .listening || state == .thinking || state == .speaking {
                ZStack {
                    Ellipse()
                        .fill(state.eyeColor)
                        .frame(width: 12.4 * s, height: 14.8 * s)
                        .position(x: 42.0 * s, y: 47.0 * s)

                    Ellipse()
                        .fill(state.eyeColor)
                        .frame(width: 12.4 * s, height: 14.8 * s)
                        .position(x: 60.0 * s, y: 47.0 * s)
                }
                .scaleEffect(x: 1.0, y: (state == .idle && isBlinking) ? 0.1 : 1.0, anchor: UnitPoint(x: 0.51, y: 0.47))
                .transition(.opacity)
            }

            // Happy squint eyes
            if state == .happy {
                ZStack {
                    HappyEyeArch()
                        .fill(state.eyeColor)
                        .frame(width: 14.4 * s, height: 7.6 * s)
                        .position(x: 42.0 * s, y: 43.8 * s)

                    HappyEyeArch()
                        .fill(state.eyeColor)
                        .frame(width: 14.4 * s, height: 7.6 * s)
                        .position(x: 60.0 * s, y: 43.8 * s)
                }
                .transition(.opacity)
            }

            // Mad narrowed eyes
            if state == .mad {
                ZStack {
                    Ellipse()
                        .fill(state.eyeColor)
                        .frame(width: 12.8 * s, height: 7.2 * s)
                        .rotationEffect(.degrees(10))
                        .position(x: 42.0 * s, y: 47.0 * s)

                    Ellipse()
                        .fill(state.eyeColor)
                        .frame(width: 12.8 * s, height: 7.2 * s)
                        .rotationEffect(.degrees(-10))
                        .position(x: 60.0 * s, y: 47.0 * s)
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state)
    }

    // MARK: - Computed Pose Transforms

    private var eyeBaseScale: CGFloat {
        switch state {
        case .listening: return 1.14
        case .speaking: return 1.04
        default: return 1.0
        }
    }

    private var eyeBaseOffset: CGSize {
        switch state {
        case .thinking: return CGSize(width: 2.6, height: -3.6)
        default: return .zero
        }
    }

    private var bodyScaleX: CGFloat {
        guard !reduceMotion else { return 1.0 }
        var x = oneShotScaleX
        if state == .idle && breatheToggle { x *= 1.018 }
        if state == .speaking && speechToggle { x *= 1.04 }
        return x
    }

    private var bodyScaleY: CGFloat {
        guard !reduceMotion else { return 1.0 }
        var y = oneShotScaleY
        if state == .idle && breatheToggle { y *= 0.982 }
        if state == .speaking && speechToggle { y *= 1.04 }
        return y
    }

    private var bodyOffsetX: CGFloat {
        guard !reduceMotion else { return 0 }
        var x = oneShotOffsetX
        if state == .thinking {
            x += swayToggle ? 2.4 : -2.4
        }
        return x
    }

    private var bodyOffsetY: CGFloat {
        guard !reduceMotion else { return 0 }
        var y = oneShotOffsetY
        if state == .listening {
            y += 2.6
        }
        return y
    }

    private var bodyRotation: Double {
        guard !reduceMotion else { return 0 }
        switch state {
        case .listening: return -3.0
        case .thinking: return swayToggle ? 2.0 : -2.0
        default: return 0
        }
    }

    // MARK: - Animation Orchestration

    private func startStateAnimations() {
        let token = UUID()
        animationToken = token
        breatheToggle = false
        swayToggle = false
        speechToggle = false
        isBlinking = false
        lookOffset = .zero
        lookScale = 1.0
        oneShotScaleX = 1.0
        oneShotScaleY = 1.0
        oneShotOffsetX = 0
        oneShotOffsetY = 0

        guard !reduceMotion else { return }

        switch state {
        case .idle:
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                breatheToggle = true
            }
            startBlinkLoop(token: token)
            if isLookingAround {
                startLookAroundLoop(token: token)
            }

        case .listening:
            // Soft pulse
            withAnimation(.spring(response: 0.36, dampingFraction: 0.6)) {
                oneShotScaleX = 1.05
                oneShotScaleY = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                guard animationToken == token else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    oneShotScaleX = 1.0
                    oneShotScaleY = 1.0
                }
            }

        case .thinking:
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                swayToggle = true
            }

        case .happy:
            // Celebratory bounce
            withAnimation(.easeOut(duration: 0.24)) {
                oneShotOffsetY = -7
                oneShotScaleX = 0.96
                oneShotScaleY = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                guard animationToken == token else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    oneShotOffsetY = 0
                    oneShotScaleX = 1.06
                    oneShotScaleY = 0.94
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                guard animationToken == token else { return }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.65)) {
                    oneShotOffsetY = 0
                    oneShotScaleX = 1.0
                    oneShotScaleY = 1.0
                }
            }

        case .mad:
            // Squish & horizontal shake
            withAnimation(.easeOut(duration: 0.11)) {
                oneShotScaleX = 1.13
                oneShotScaleY = 0.86
            }
            let shakes: [(Double, CGFloat, CGFloat, CGFloat)] = [
                (0.12, -3.0, 0.97, 1.03),
                (0.22, 3.0, 0.97, 1.03),
                (0.32, -2.0, 1.0, 1.0),
                (0.42, 2.0, 1.0, 1.0),
                (0.52, 0.0, 1.0, 1.0)
            ]
            for (delay, dx, sx, sy) in shakes {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    guard animationToken == token else { return }
                    withAnimation(.easeInOut(duration: 0.09)) {
                        oneShotOffsetX = dx
                        oneShotScaleX = sx
                        oneShotScaleY = sy
                    }
                }
            }

        case .speaking:
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                speechToggle = true
            }
        }
    }

    private func startBlinkLoop(token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            guard animationToken == token, state == .idle else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                guard animationToken == token else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    isBlinking = false
                }
                startBlinkLoop(token: token)
            }
        }
    }

    private func startLookAroundLoop(token: UUID? = nil) {
        let activeToken = token ?? animationToken
        let steps: [(Double, CGSize, CGFloat)] = [
            (0.0, CGSize(width: -4.5, height: -1.0), 1.03),
            (1.1, CGSize(width: 4.8, height: -1.2), 1.03),
            (2.4, CGSize(width: 0.0, height: 1.5), 1.0),
            (3.2, .zero, 1.0)
        ]
        for (delay, offset, scale) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard animationToken == activeToken, state == .idle, isLookingAround else { return }
                withAnimation(.easeInOut(duration: 0.55)) {
                    lookOffset = offset
                    lookScale = scale
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            guard animationToken == activeToken, state == .idle, isLookingAround else { return }
            startLookAroundLoop(token: activeToken)
        }
    }
}
