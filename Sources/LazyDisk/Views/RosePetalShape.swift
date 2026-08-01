import SwiftUI

struct RosePetalShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        guard outerRadius > innerRadius + 1 else { return path }

        let sa = startAngle * .pi / 180
        let ea = endAngle * .pi / 180
        let span = ea - sa

        let cr = min(
            cornerRadius,
            (outerRadius - innerRadius) * 0.45,
            outerRadius * span * 0.35
        )

        let innerStart = polar(center, innerRadius, sa)
        let innerEnd = polar(center, innerRadius, ea)

        let cornerOffset = Double(cr / outerRadius)
        let outerArcStart = sa + cornerOffset
        let outerArcEnd = ea - cornerOffset

        let outerArcStartPt = polar(center, outerRadius, outerArcStart)

        path.move(to: innerStart)

        let preOuterStart = polar(center, outerRadius - cr, sa)
        path.addLine(to: preOuterStart)
        path.addQuadCurve(
            to: outerArcStartPt,
            control: polar(center, outerRadius, sa)
        )

        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .radians(outerArcStart),
            endAngle: .radians(outerArcEnd),
            clockwise: false
        )

        let preOuterEnd = polar(center, outerRadius - cr, ea)
        path.addQuadCurve(to: preOuterEnd, control: polar(center, outerRadius, ea))
        path.addLine(to: innerEnd)

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .radians(ea),
            endAngle: .radians(sa),
            clockwise: true
        )

        path.closeSubpath()
        return path
    }

    private func polar(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}
