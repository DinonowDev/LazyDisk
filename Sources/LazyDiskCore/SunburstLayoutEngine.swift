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

    public var midAngle: CGFloat { startAngle + spanAngle / 2 }

    public init(
        item: DiskItem,
        colorIndex: Int,
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat,
        depth: Int,
        startAngle: CGFloat,
        endAngle: CGFloat,
        spanAngle: CGFloat
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

        public static let standard = Config(
            hubRadius: 0.24,
            maxOuterRadius: 0.38,
            gapDegrees: 1.2,
            maxChildrenPerNode: 8,
            maxDepth: 2,
            minSliceDegrees: 0.8
        )

        public static let daisyDisk = Config(
            hubRadius: 0.14,
            maxOuterRadius: 0.38,
            gapDegrees: 0.6,
            maxChildrenPerNode: 12,
            maxDepth: 3,
            minSliceDegrees: 0.4
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
            inheritedHue: CGFloat?,
            inheritedSaturation: CGFloat?,
            inheritedBrightness: CGFloat?
        ) {
            let visible = levelItems.filter { $0.size > 0 || $0.isScanning }
            guard !visible.isEmpty else { return }

            let levelTotal = max(visible.reduce(Int64(0)) { $0 + $1.size }, 1)
            let count = CGFloat(visible.count)
            let gaps = max(0, count - 1) * config.gapDegrees
            let usable = max(availableAngle - gaps, 1)
            var cursor = startAngle

            for (index, item) in visible.enumerated() {
                let fraction = CGFloat(item.size) / CGFloat(levelTotal)
                var span = fraction * usable
                if item.size > 0 { span = max(span, config.minSliceDegrees) }

                let hue: CGFloat
                let saturation: CGFloat
                let brightness: CGFloat
                let colorIndex: Int

                if let inheritedHue, let inheritedSaturation, let inheritedBrightness {
                    hue = inheritedHue
                    saturation = max(0.45, inheritedSaturation - CGFloat(depth) * 0.04)
                    let siblingSpread = visible.count > 1
                        ? (CGFloat(index) / CGFloat(visible.count - 1) - 0.5) * 0.06
                        : 0
                    brightness = min(
                        0.92,
                        inheritedBrightness + CGFloat(depth) * 0.07 + siblingSpread
                    )
                    colorIndex = Int(hue * 1000) + depth * 100 + index
                } else {
                    hue = CGFloat(index) / CGFloat(max(visible.count, 1))
                    saturation = 0.78
                    brightness = 0.58
                    colorIndex = colorCursor
                    colorCursor += 1
                }

                segments.append(SunburstSegment(
                    item: item,
                    colorIndex: colorIndex,
                    hue: hue,
                    saturation: saturation,
                    brightness: brightness,
                    depth: depth,
                    startAngle: cursor,
                    endAngle: cursor + span,
                    spanAngle: span
                ))

                if item.isDirectory, !item.isVirtual,
                   depth < config.maxDepth,
                   let children = childrenByParentPath[PathUtils.resolved(item.url).path],
                   !children.isEmpty, span > 2 {
                    let sorted = children
                        .filter { $0.size > 0 || $0.isScanning }
                        .sorted { $0.size > $1.size }
                        .prefix(config.maxChildrenPerNode)
                    layoutLevel(
                        Array(sorted),
                        depth: depth + 1,
                        startAngle: cursor,
                        availableAngle: span,
                        inheritedHue: hue,
                        inheritedSaturation: saturation,
                        inheritedBrightness: brightness
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
            inheritedHue: nil,
            inheritedSaturation: nil,
            inheritedBrightness: nil
        )
        return segments
    }

    public static func maxDepth(in segments: [SunburstSegment]) -> Int {
        segments.map(\.depth).max() ?? 0
    }

    public static func innerRadiusRatio(depth: Int, maxDepth: Int, config: Config = .standard) -> CGFloat {
        let ringCount = CGFloat(max(maxDepth, 0) + 1)
        let ringWidth = (config.maxOuterRadius - config.hubRadius) / ringCount
        return config.hubRadius + CGFloat(depth) * ringWidth
    }

    public static func outerRadiusRatio(depth: Int, maxDepth: Int, config: Config = .standard) -> CGFloat {
        let inner = innerRadiusRatio(depth: depth, maxDepth: maxDepth, config: config)
        let ringCount = CGFloat(max(maxDepth, 0) + 1)
        let ringWidth = (config.maxOuterRadius - config.hubRadius) / ringCount
        return inner + ringWidth
    }
}
