import Foundation

public struct SunburstSegment: Identifiable, Equatable {
    public var id: String { "\(item.id.uuidString)-\(depth)" }
    public let item: DiskItem
    public let colorIndex: Int
    public let hue: CGFloat
    public let saturation: CGFloat
    public let brightness: CGFloat
    public let depth: Int
    public let startAngle: CGFloat
    public let endAngle: CGFloat
    public let spanAngle: CGFloat
    public let innerRadiusRatio: CGFloat
    public let outerRadiusRatio: CGFloat

    public var midAngle: CGFloat { startAngle + spanAngle / 2 }
    public var midRadiusRatio: CGFloat { (innerRadiusRatio + outerRadiusRatio) / 2 }

    public init(
        item: DiskItem,
        colorIndex: Int,
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat,
        depth: Int,
        startAngle: CGFloat,
        endAngle: CGFloat,
        spanAngle: CGFloat,
        innerRadiusRatio: CGFloat,
        outerRadiusRatio: CGFloat
    ) {
        self.item = item
        self.colorIndex = colorIndex
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.depth = depth
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.spanAngle = spanAngle
        self.innerRadiusRatio = innerRadiusRatio
        self.outerRadiusRatio = outerRadiusRatio
    }
}

public enum SunburstLayoutEngine {
    public struct Config: Sendable {
        public let hubRadius: CGFloat
        public let maxOuterRadius: CGFloat
        public let gapDegrees: CGFloat
        public let maxChildrenPerNode: Int
        public let maxDepth: Int
        public let minSliceDegrees: CGFloat
        public let minRadialRatio: CGFloat
        public let radialGapRatio: CGFloat

        public static let standard = Config(
            hubRadius: 0.168,
            maxOuterRadius: 0.46,
            gapDegrees: 1.2,
            maxChildrenPerNode: 32,
            maxDepth: 3,
            minSliceDegrees: 0.8,
            minRadialRatio: 0.006,
            radialGapRatio: 0.004
        )

        public static let daisyDisk = Config(
            hubRadius: 0.098,
            maxOuterRadius: 0.46,
            gapDegrees: 0.6,
            maxChildrenPerNode: 32,
            maxDepth: 3,
            minSliceDegrees: 0.4,
            minRadialRatio: 0.005,
            radialGapRatio: 0.003
        )
    }

    private static let defaultConfig = Config.standard

    public static func build(
        items: [DiskItem],
        totalSize: Int64,
        childrenByParentPath: [String: [DiskItem]],
        config: Config = .standard
    ) -> [SunburstSegment] {
        guard !items.isEmpty else { return [] }

        var segments: [SunburstSegment] = []
        var colorCursor = 0

        func layoutLevel(
            _ levelItems: [DiskItem],
            depth: Int,
            startAngle: CGFloat,
            availableAngle: CGFloat,
            innerRadius: CGFloat,
            branchHue: CGFloat?,
            branchRelativeDepth: Int
        ) {
            let visible = levelItems.filter { $0.size > 0 || $0.isScanning }
            guard !visible.isEmpty else { return }

            let levelTotal = max(visible.reduce(Int64(0)) { $0 + $1.size }, 1)
            let count = CGFloat(visible.count)
            let gaps = max(0, count - 1) * config.gapDegrees
            let usableAngle = max(availableAngle - gaps, 1)
            let radialBudget = max(config.maxOuterRadius - innerRadius, config.minRadialRatio)
            var cursor = startAngle

            for (index, item) in visible.enumerated() {
                let fraction = CGFloat(item.size) / CGFloat(levelTotal)
                var span = fraction * usableAngle
                if item.size > 0 { span = max(span, config.minSliceDegrees) }

                var radialThickness = fraction * radialBudget
                if item.size > 0 { radialThickness = max(radialThickness, config.minRadialRatio) }

                let childPath = item.isDirectory && !item.isVirtual
                    ? childrenByParentPath[PathUtils.resolved(item.url).path]
                    : nil
                let hasChildren = depth < config.maxDepth
                    && childPath.map { !$0.isEmpty } == true

                if hasChildren {
                    let remainingDepth = CGFloat(config.maxDepth - depth)
                    let reserved = remainingDepth * (config.minRadialRatio + config.radialGapRatio)
                    radialThickness = min(radialThickness, max(config.minRadialRatio, radialBudget - reserved))
                }

                let outerRadius = min(innerRadius + radialThickness, config.maxOuterRadius)

                let hue: CGFloat
                let relativeDepth: Int
                let colorIndex: Int

                if let branchHue {
                    hue = branchHue
                    relativeDepth = branchRelativeDepth
                    colorIndex = Int(hue * 1000) + relativeDepth * 100 + index
                } else {
                    hue = rootHue(for: index, count: visible.count)
                    relativeDepth = 0
                    colorIndex = colorCursor
                    colorCursor += 1
                }

                let components = branchColorComponents(hue: hue, relativeDepth: relativeDepth)
                let saturation = components.saturation
                let brightness = components.brightness

                segments.append(SunburstSegment(
                    item: item,
                    colorIndex: colorIndex,
                    hue: hue,
                    saturation: saturation,
                    brightness: brightness,
                    depth: depth,
                    startAngle: cursor,
                    endAngle: cursor + span,
                    spanAngle: span,
                    innerRadiusRatio: innerRadius,
                    outerRadiusRatio: outerRadius
                ))

                if item.isDirectory, !item.isVirtual,
                   depth < config.maxDepth,
                   let children = childPath,
                   !children.isEmpty, span > 2,
                   outerRadius + config.radialGapRatio < config.maxOuterRadius {
                    let sorted = children
                        .filter { $0.size > 0 || $0.isScanning }
                        .sorted { $0.size > $1.size }
                        .prefix(config.maxChildrenPerNode)
                    layoutLevel(
                        Array(sorted),
                        depth: depth + 1,
                        startAngle: cursor,
                        availableAngle: span,
                        innerRadius: outerRadius + config.radialGapRatio,
                        branchHue: hue,
                        branchRelativeDepth: relativeDepth + 1
                    )
                }

                cursor += span
                if index < visible.count - 1 { cursor += config.gapDegrees }
            }
        }

        layoutLevel(
            items,
            depth: 0,
            startAngle: -90,
            availableAngle: 360,
            innerRadius: config.hubRadius,
            branchHue: nil,
            branchRelativeDepth: 0
        )
        return segments
    }

    public static func maxDepth(in segments: [SunburstSegment]) -> Int {
        segments.map(\.depth).max() ?? 0
    }

    /// Evenly spaced hues for top-level branches (DaisyDisk-style spectrum).
    static func rootHue(for index: Int, count: Int) -> CGFloat {
        let offset: CGFloat = 0.08
        return (offset + CGFloat(index) / CGFloat(max(count, 1))).truncatingRemainder(dividingBy: 1)
    }

    /// Same hue per branch; inner rings darker, outer rings lighter.
    public static func branchColorComponents(
        hue: CGFloat,
        relativeDepth: Int
    ) -> (saturation: CGFloat, brightness: CGFloat) {
        let depth = CGFloat(relativeDepth)
        let saturation = max(0.50, 0.86 - depth * 0.10)
        let brightness = min(0.96, 0.44 + depth * 0.14)
        return (saturation, brightness)
    }

}
