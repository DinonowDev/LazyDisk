import SwiftUI

enum SunburstAppearance {
    case standard
    case daisyDisk
}

struct SunburstChartView: View {
    let segments: [SunburstSegment]
    let totalSize: Int64
    let centerTitle: String
    let centerSubtitle: String?
    var appearance: SunburstAppearance = .standard
    var layoutConfig: SunburstLayoutEngine.Config = .standard
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void
    var onCenterTap: (() -> Void)?
    var onAddToCollector: ((DiskItem) -> Void)?

    @State private var animationProgress: CGFloat = 0
    @State private var isPointerOverChart = false
    @State private var pointerHoveredID: UUID?

    private var isDaisyDisk: Bool { appearance == .daisyDisk }
    private let hoverAnimation: Animation = .easeOut(duration: 0.1)

    private var effectiveHoveredID: UUID? {
        isPointerOverChart ? pointerHoveredID : hoveredID
    }

    private var maxDepth: Int {
        SunburstLayoutEngine.maxDepth(in: segments)
    }

    private var colorPalette: [Color] {
        isDaisyDisk ? DiskColors.daisyDiskPalette : DiskColors.palette
    }

    var body: some View {
        GeometryReader { geometry in
            let chartSize = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                if segments.isEmpty {
                    emptyState
                } else {
                    segmentsLayer(chartSize: chartSize, center: center)
                    centerHub(chartSize: chartSize, center: center)
                    labelsLayer(chartSize: chartSize, center: center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if let item = hitTest(at: value.location, chartSize: chartSize, center: center) {
                            onSelect(item)
                        } else if isDaisyDisk, isInCenterHub(at: value.location, chartSize: chartSize, center: center) {
                            onCenterTap?()
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isPointerOverChart = true
                    let newID = hitTest(at: location, chartSize: chartSize, center: center)?.id
                    guard pointerHoveredID != newID else { return }
                    pointerHoveredID = newID
                    Task { @MainActor in onHover(newID) }
                case .ended:
                    isPointerOverChart = false
                    guard pointerHoveredID != nil else { return }
                    pointerHoveredID = nil
                    Task { @MainActor in onHover(nil) }
                }
            }
        }
        .onAppear {
            animationProgress = 0
            withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                animationProgress = 1
            }
        }
        .onChange(of: segments.map(\.id)) { _ in
            animationProgress = 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                animationProgress = 1
            }
        }
    }

    private func segmentsLayer(chartSize: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach(segments) { segment in
                let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(
                    depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
                )
                let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(
                    depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
                )
                let isHovered = effectiveHoveredID == segment.item.id
                let dimmed = effectiveHoveredID != nil && !isHovered
                let animatedEnd = segment.startAngle + segment.spanAngle * animationProgress
                let cornerRadius: CGFloat = isDaisyDisk ? 1 : (segment.depth == 0 ? 6 : 3)

                DonutSegmentShape(
                    startAngle: Double(segment.startAngle),
                    endAngle: Double(animatedEnd),
                    innerRadius: innerR,
                    outerRadius: outerR,
                    cornerRadius: cornerRadius
                )
                .fill(segmentFill(segment: segment, isHovered: isHovered))
                .shadow(
                    color: isDaisyDisk
                        ? .clear
                        : DiskColors.color(for: segment.colorIndex).opacity(isHovered ? 0.35 : 0.12),
                    radius: isHovered ? 10 : 4,
                    y: isHovered ? 2 : 1
                )
                .overlay {
                    DonutSegmentShape(
                        startAngle: Double(segment.startAngle),
                        endAngle: Double(animatedEnd),
                        innerRadius: innerR,
                        outerRadius: outerR,
                        cornerRadius: cornerRadius
                    )
                    .stroke(
                        isDaisyDisk
                            ? Color(white: 0.12)
                            : Color.white.opacity(isHovered ? 0.45 : 0.15),
                        lineWidth: isDaisyDisk ? 1.5 : (isHovered ? 1.5 : 0.75)
                    )
                }
                .scaleEffect(isDaisyDisk ? 1 : (isHovered ? 1.02 : 1), anchor: .center)
                .opacity(dimmed ? (isDaisyDisk ? 0.5 : 0.4) : 1)
                .animation(hoverAnimation, value: isHovered)
                .frame(width: chartSize, height: chartSize)
                .position(center)
                .onDrag {
                    NSItemProvider(object: segment.item.url as NSURL)
                }
                .contextMenu {
                    if !segment.item.isVirtual {
                        Button(L10n.addToCollector) { onAddToCollector?(segment.item) }
                        if segment.item.isDirectory {
                            Button(L10n.open) { onSelect(segment.item) }
                        }
                    }
                }
            }
        }
    }

    private func segmentFill(segment: SunburstSegment, isHovered: Bool) -> AnyShapeStyle {
        if isDaisyDisk {
            let color = DiskColors.spectrumColor(
                hue: segment.hue,
                saturation: segment.saturation,
                brightness: segment.brightness,
                depth: segment.depth,
                isHovered: isHovered
            )
            return AnyShapeStyle(color)
        }
        return AnyShapeStyle(DiskColors.gradient(for: segment.colorIndex, depth: segment.depth, palette: colorPalette))
    }

    private func labelsLayer(chartSize: CGFloat, center: CGPoint) -> some View {
        ZStack {
            ForEach(segments.filter { $0.depth == 0 }) { segment in
                segmentLabel(segment, chartSize: chartSize, center: center, fontSize: isDaisyDisk ? 11 : 10, minSpan: 12)
            }
            ForEach(segments.filter { $0.depth == 1 }) { segment in
                segmentLabel(segment, chartSize: chartSize, center: center, fontSize: isDaisyDisk ? 10 : 9, minSpan: 8)
            }
            ForEach(segments.filter { $0.depth == 2 }) { segment in
                segmentLabel(segment, chartSize: chartSize, center: center, fontSize: isDaisyDisk ? 9 : 8, minSpan: 6)
            }
        }
    }

    @ViewBuilder
    private func segmentLabel(
        _ segment: SunburstSegment,
        chartSize: CGFloat,
        center: CGPoint,
        fontSize: CGFloat,
        minSpan: CGFloat
    ) -> some View {
        if segment.spanAngle > minSpan {
            let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(
                depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
            )
            let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(
                depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
            )
            let radius: CGFloat = {
                switch segment.depth {
                case 0:
                    return isDaisyDisk ? outerR + 18 : outerR + 22
                case 1:
                    return (innerR + outerR) / 2
                default:
                    return innerR + (outerR - innerR) * 0.55
                }
            }()
            let angle = (segment.midAngle - 90) * .pi / 180
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            let isHovered = effectiveHoveredID == segment.item.id
            let showsSize = segment.depth <= 1 || segment.spanAngle > 14

            VStack(spacing: 1) {
                Text(segment.item.displayName)
                    .font(.system(size: fontSize, weight: isHovered ? .bold : .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.65)
                if showsSize {
                    Text(segment.item.formattedSize)
                        .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                        .foregroundStyle(isDaisyDisk ? Color.white.opacity(0.82) : Color.secondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .padding(.horizontal, segment.depth == 0 ? 7 : 5)
            .padding(.vertical, segment.depth == 0 ? 4 : 2)
            .background {
                RoundedRectangle(cornerRadius: segment.depth == 0 ? 7 : 5, style: .continuous)
                    .fill(labelBackground(isHovered: isHovered))
                    .shadow(color: .black.opacity(isDaisyDisk ? 0.35 : 0.08), radius: 4, y: 1)
            }
            .foregroundStyle(labelForeground(depth: segment.depth, isHovered: isHovered))
            .opacity(effectiveHoveredID == nil || isHovered ? 1 : 0.4)
            .position(x: x, y: y)
            .allowsHitTesting(false)
        }
    }

    private func labelBackground(isHovered: Bool) -> Color {
        if isDaisyDisk {
            return Color.black.opacity(isHovered ? 0.72 : 0.58)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.92)
    }

    private func labelForeground(depth: Int, isHovered: Bool) -> Color {
        if isDaisyDisk {
            return .white.opacity(isHovered ? 1 : 0.94)
        }
        return depth == 0 ? Color.primary : Color.primary.opacity(0.9)
    }

    private func centerHub(chartSize: CGFloat, center: CGPoint) -> some View {
        let hubRatio = isDaisyDisk ? layoutConfig.hubRadius * 1.1 : ChartMetrics.hubRadiusRatio * 1.85
        let hubSize = chartSize * hubRatio

        return ZStack {
            Circle()
                .fill(isDaisyDisk ? Color(white: 0.10) : Color(nsColor: .controlBackgroundColor))
                .shadow(color: isDaisyDisk ? .clear : .black.opacity(0.08), radius: 10, y: 3)
            if !isDaisyDisk {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }

            VStack(spacing: isDaisyDisk ? 2 : 4) {
                if !isDaisyDisk {
                    Text(centerTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.75)
                }
                Text(totalSize > 0 ? ByteFormatter.string(from: totalSize) : "—")
                    .font(.system(
                        size: isDaisyDisk ? 22 : 18,
                        weight: .bold,
                        design: isDaisyDisk ? .default : .rounded
                    ))
                    .foregroundStyle(isDaisyDisk ? .white : .primary)
                    .environment(\.layoutDirection, .leftToRight)
                if let centerSubtitle {
                    Text(centerSubtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                if !isDaisyDisk {
                    Text(L10n.itemsCount(segments.filter { $0.depth == 0 }.count))
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: hubSize, height: hubSize)
        .position(center)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "circle.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.chartNoData)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func isInCenterHub(at point: CGPoint, chartSize: CGFloat, center: CGPoint) -> Bool {
        let hubRatio = layoutConfig.hubRadius * 1.1
        let hubRadius = chartSize * hubRatio / 2
        let dx = point.x - center.x
        let dy = point.y - center.y
        return sqrt(dx * dx + dy * dy) <= hubRadius
    }

    private func hitTest(at point: CGPoint, chartSize: CGFloat, center: CGPoint) -> DiskItem? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx) * 180 / .pi

        for segment in segments.reversed() {
            let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(
                depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
            )
            let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(
                depth: segment.depth, maxDepth: maxDepth, config: layoutConfig
            )
            guard distance >= innerR - 2, distance <= outerR + 4 else { continue }

            let end = segment.startAngle + segment.spanAngle * animationProgress
            var start = segment.startAngle
            var test = angle
            while start < -180 { start += 360 }
            while test < start - 180 { test += 360 }
            if test >= start && test <= end {
                return segment.item
            }
        }
        return nil
    }
}
