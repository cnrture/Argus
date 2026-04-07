import SwiftUI

struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let topR = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let botR = min(bottomCornerRadius, rect.width / 2, rect.height / 2)

        var path = Path()

        // Start top-left after top corner radius
        path.move(to: CGPoint(x: rect.minX + topR, y: rect.minY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY))

        // Top-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topR),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - botR))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - botR, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + botR, y: rect.maxY))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - botR),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topR))

        // Top-left corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
