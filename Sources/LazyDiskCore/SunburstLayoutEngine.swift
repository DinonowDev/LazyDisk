import Foundation

public struct SunburstSegment: Identifiable, Equatable {
    public var id: String { "\(item.id.uuidString)-\(depth)" }
    public let item: DiskItem
    public let colorIndex: Int
    public let depth: Int
    public let startAngle: CGFloat
    public let endAngle: CGFloat
    public let spanAngle: CGFloat

    public var midAngle: CGFloat { startAngle + spanAngle / 2 }

    public init(
        item: DiskItem,
        colorIndex: Int,
        depth: Int,
        startAngle: CGFloat,
        endAngle: CGFloat,
        spanAngle: CGFloat
    ) {
        self.item = item
        self.colorIndex = colorIndex
        self.depth = depth
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.spanAngle = spanAngle
    }
}

public enum SunburstLayoutEngine {
    private static let gapDegrees: CGFloat = 1.2
    private static let maxChildrenPerNode = 8
    private static let minSliceDegrees: CGFloat = 0.8

    public static func build(
        items: [DiskItem],
        totalSize: Int64,
        childrenByParentID: [UUID: [DiskItem]]
    ) -> [SunburstSegment] {
        guard !items.isEmpty else { return [] }

        var segments: [SunburstSegment] = []
        var colorCursor = 0

        func layoutLevel(
            _ levelItems: [DiskItem],
            depth: Int,
            startAngle: CGFloat,
            availableAngle: CGFloat,
            inheritedColor: Int?
        ) {
            let visible = levelItems.filter { $0.size > 0 || $0.isScanning }
            guard !visible.isEmpty else { return }

            let levelTotal = max(visible.reduce(Int64(0)) { $0 + $1.size }, 1)
            let count = CGFloat(visible.count)
            let gaps = max(0, count - 1) * gapDegrees
            let usable = max(availableAngle - gaps, 1)
            var cursor = startAngle

            for (index, item) in visible.enumerated() {
                let fraction = CGFloat(item.size) / CGFloat(levelTotal)
                var span = fraction * usable
                if item.size > 0 { span = max(span, minSliceDegrees) }

                let colorIndex = inheritedColor ?? colorCursor
                if inheritedColor == nil { colorCursor += 1 }

                segments.append(SunburstSegment(
                    item: item,
                    colorIndex: colorIndex,
                    depth: depth,
                    startAngle: cursor,
                    endAngle: cursor + span,
                    spanAngle: span
                ))

                if item.isDirectory, !item.isVirtual,
                   let children = childrenByParentID[item.id],
                   !children.isEmpty, span > 2 {
                    let sorted = children
                        .filter { $0.size > 0 }
                        .sorted { $0.size > $1.size }
                        .prefix(maxChildrenPerNode)
                    layoutLevel(
                        Array(sorted),
                        depth: depth + 1,
                        startAngle: cursor,
                        availableAngle: span,
                        inheritedColor: colorIndex
                    )
                }

                cursor += span
                if index < visible.count - 1 { cursor += gapDegrees }
            }
        }

        layoutLevel(items, depth: 0, startAngle: -90, availableAngle: 360, inheritedColor: nil)
        return segments
    }

    public static func maxDepth(in segments: [SunburstSegment]) -> Int {
        segments.map(\.depth).max() ?? 0
    }

    public static func innerRadiusRatio(depth: Int, maxDepth: Int) -> CGFloat {
        let hub: CGFloat = 0.16
        let usable: CGFloat = 0.36
        let ringCount = CGFloat(max(maxDepth, 0) + 1)
        let ringWidth = usable / ringCount
        return hub + CGFloat(depth) * ringWidth
    }

    public static func outerRadiusRatio(depth: Int, maxDepth: Int) -> CGFloat {
        let inner = innerRadiusRatio(depth: depth, maxDepth: maxDepth)
        let ringCount = CGFloat(max(maxDepth, 0) + 1)
        let ringWidth = 0.36 / ringCount
        return inner + ringWidth - 0.004
    }
}
