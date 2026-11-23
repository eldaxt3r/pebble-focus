import SwiftUI

/// Exact organic Pebble silhouette from the HTML prototype (tuft removed), normalized from 0..100 viewBox.
public struct PebbleBodyShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100.0
        let sy = rect.height / 100.0
        let ox = rect.minX
        let oy = rect.minY

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * sx, y: oy + y * sy)
        }

        var path = Path()
        // M50,19 C67,19 81,31 81.5,47 C82,63 75.5,77 62,82 C49,86.5 33,84 24.5,75 C16.5,66.5 16.5,53 18,43 C20,29 33,19 50,19 Z
        path.move(to: pt(50, 19))
        path.addCurve(to: pt(81.5, 47), control1: pt(67, 19), control2: pt(81, 31))
        path.addCurve(to: pt(62, 82), control1: pt(82, 63), control2: pt(75.5, 77))
        path.addCurve(to: pt(24.5, 75), control1: pt(49, 86.5), control2: pt(33, 84))
        path.addCurve(to: pt(18, 43), control1: pt(16.5, 66.5), control2: pt(16.5, 53))
        path.addCurve(to: pt(50, 19), control1: pt(20, 29), control2: pt(33, 19))
        path.closeSubpath()
        return path
    }
}

/// Happy squint eye arch (semicircle upward)
public struct HappyEyeArch: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2.0,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
