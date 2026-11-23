import SwiftUI
import AppKit

/// Shared Smoked Charcoal Matte Glass design system:
/// Deep #1B1C1E -> #131416 surfaces, subtle dot-matrix texture, recessed input wells, and 1px specular rims.
public enum PebbleTheme {
    public static let windowTop = Color(red: 24/255, green: 25/255, blue: 27/255).opacity(0.88)
    public static let windowBottom = Color(red: 16/255, green: 17/255, blue: 19/255).opacity(0.94)

    public static let cardTop = Color(red: 34/255, green: 35/255, blue: 38/255).opacity(0.86)
    public static let cardBottom = Color(red: 22/255, green: 23/255, blue: 25/255).opacity(0.92)

    public static let wellBackground = Color(red: 15/255, green: 16/255, blue: 18/255).opacity(0.85)
    public static let elevatedSurface = Color(red: 42/255, green: 43/255, blue: 47/255).opacity(0.92)

    public static let textPrimary = Color(red: 244/255, green: 244/255, blue: 246/255)
    public static let textSecondary = Color(red: 146/255, green: 148/255, blue: 154/255)
    public static let textTertiary = Color(red: 102/255, green: 104/255, blue: 110/255)

    public static var rimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.16),
                Color.white.opacity(0.05),
                Color.white.opacity(0.02)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var innerRimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.09),
                Color.white.opacity(0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Ultra-subtle dot-matrix pattern inside smoked charcoal cards (drawn via Canvas for 0 overhead).
public struct SubtleDotGridBackground: View {
    public var spacing: CGFloat = 14
    public var dotOpacity: Double = 0.045

    public init(spacing: CGFloat = 14, dotOpacity: Double = 0.045) {
        self.spacing = spacing
        self.dotOpacity = dotOpacity
    }

    public var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    let x = CGFloat(c) * spacing + spacing * 0.5
                    let y = CGFloat(r) * spacing + spacing * 0.5
                    let rect = CGRect(x: x - 0.65, y: y - 0.65, width: 1.3, height: 1.3)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(dotOpacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Reusable Smoked Charcoal Card container matching the reference aesthetic.
public struct SmokedGlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let paddingAmount: CGFloat
    private let showDots: Bool
    private let content: Content

    public init(
        cornerRadius: CGFloat = 20,
        padding: CGFloat = 18,
        showDots: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.paddingAmount = padding
        self.showDots = showDots
        self.content = content()
    }

    public var body: some View {
        content
            .padding(paddingAmount)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [PebbleTheme.cardTop, PebbleTheme.cardBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if showDots {
                        SubtleDotGridBackground()
                            .mask(
                                RadialGradient(
                                    colors: [.white.opacity(0.9), .clear],
                                    center: .topTrailing,
                                    startRadius: 10,
                                    endRadius: 320
                                )
                            )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PebbleTheme.rimGradient, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
    }
}

/// Native behind-window macOS blur backdrop.
public struct LiquidGlassBackdrop: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
