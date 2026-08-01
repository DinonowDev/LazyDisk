import SwiftUI

struct PlacedChartLabel: Identifiable {
    let id: UUID
    let layout: SegmentLayout
    let chipCenter: CGPoint
    let elbowPoint: CGPoint
    let lineStart: CGPoint
    let isRightSide: Bool
}

enum ChartLabelLayoutEngine {
    static var chipWidth: CGFloat { L10n.isRTL ? 148 : 112 }
    static var chipHeight: CGFloat { L10n.isRTL ? 40 : 36 }
    static let minSpacing: CGFloat = 4

    static func place(
        layouts: [SegmentLayout],
        center: CGPoint,
        outerRadius: CGFloat,
        canvasSize: CGSize,
        hoveredID: UUID?,
        animationProgress: CGFloat
    ) -> [PlacedChartLabel] {
        var candidates: [(layout: SegmentLayout, naturalY: CGFloat, isRight: Bool, elbow: CGPoint, lineStart: CGPoint)] = []

        for layout in layouts {
            let span = layout.spanAngle * animationProgress
            guard span >= 2.0 || layout.item.id == hoveredID else { continue }

            let rad = layout.midAngle * .pi / 180
            let isRight = cos(rad) >= 0

            let lineStart = CGPoint(
                x: center.x + (outerRadius + 2) * cos(rad),
                y: center.y + (outerRadius + 2) * sin(rad)
            )
            let elbow = CGPoint(
                x: center.x + (outerRadius + 20) * cos(rad),
                y: center.y + (outerRadius + 20) * sin(rad)
            )

            candidates.append((layout, elbow.y, isRight, elbow, lineStart))
        }

        var placed: [PlacedChartLabel] = []

        for isRight in [true, false] {
            let side = candidates
                .filter { $0.isRight == isRight }
                .sorted { $0.naturalY < $1.naturalY }

            var yPositions = side.map(\.naturalY)
            yPositions = resolveCollisions(yPositions, minY: 24, maxY: canvasSize.height - 24)

            for (index, item) in side.enumerated() {
                let y = yPositions[index]
                let chipX: CGFloat = isRight
                    ? min(center.x + outerRadius + 62, canvasSize.width - chipWidth / 2 - 6)
                    : max(center.x - outerRadius - 62, chipWidth / 2 + 6)

                let elbowX = isRight ? chipX - chipWidth / 2 - 8 : chipX + chipWidth / 2 + 8

                placed.append(PlacedChartLabel(
                    id: item.layout.item.id,
                    layout: item.layout,
                    chipCenter: CGPoint(x: chipX, y: y),
                    elbowPoint: CGPoint(x: elbowX, y: y),
                    lineStart: item.lineStart,
                    isRightSide: isRight
                ))
            }
        }

        return placed
    }

    private static func resolveCollisions(_ ys: [CGFloat], minY: CGFloat, maxY: CGFloat) -> [CGFloat] {
        guard !ys.isEmpty else { return ys }

        var result = ys
        let step = chipHeight + minSpacing

        for i in 1..<result.count where result[i] < result[i - 1] + step {
            result[i] = result[i - 1] + step
        }

        if let last = result.last, last + chipHeight / 2 > maxY {
            let shift = last + chipHeight / 2 - maxY
            for i in result.indices { result[i] -= shift }
        }

        if let first = result.first, first - chipHeight / 2 < minY {
            let shift = minY - (first - chipHeight / 2)
            for i in result.indices { result[i] += shift }
        }

        return result
    }
}

struct ChartLabelsOverlay: View {
    let placements: [PlacedChartLabel]
    let totalSize: Int64
    var hoveredID: UUID?

    var body: some View {
        ZStack {
            ForEach(placements) { placement in
                let color = DiskColors.color(for: placement.layout.index)
                let isHovered = hoveredID == placement.id

                Path { path in
                    path.move(to: placement.lineStart)
                    path.addLine(to: placement.elbowPoint)
                }
                .stroke(color.opacity(isHovered ? 0.9 : 0.5), lineWidth: isHovered ? 1.5 : 1)
            }

            ForEach(placements) { placement in
                let isHovered = hoveredID == placement.id
                let color = DiskColors.color(for: placement.layout.index)

                ChartLabelChip(
                    name: placement.layout.item.displayName,
                    size: placement.layout.item.formattedSize,
                    percentage: placement.layout.item.percentage(of: totalSize),
                    color: color,
                    isScanning: placement.layout.item.isScanning,
                    isHovered: isHovered
                )
                .position(placement.chipCenter)
            }
        }
    }
}

private struct ChartLabelChip: View {
    let name: String
    let size: String
    let percentage: Double
    let color: Color
    let isScanning: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: isHovered ? .bold : .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)

                if isScanning {
                    Text(L10n.scanning)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(size) · \(String(format: "%.1f", percentage))%")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: ChartLabelLayoutEngine.chipWidth)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.97))
                .shadow(color: .black.opacity(isHovered ? 0.14 : 0.07), radius: isHovered ? 6 : 3, y: 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(color.opacity(isHovered ? 0.45 : 0.18), lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.04 : 1)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
