import SwiftUI

struct SunburstChartView: View {
    let segments: [SunburstSegment]
    let totalSize: Int64
    let centerTitle: String
    let centerSubtitle: String?
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void
    var onAddToCollector: ((DiskItem) -> Void)?

    @State private var animationProgress: CGFloat = 0
    @State private var isPointerOverChart = false
    @State private var pointerHoveredID: UUID?

    private let hoverAnimation: Animation = .easeOut(duration: 0.1)

    private var effectiveHoveredID: UUID? {
        isPointerOverChart ? pointerHoveredID : hoveredID
    }

    private var maxDepth: Int {
        SunburstLayoutEngine.maxDepth(in: segments)
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
                let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
                let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
                let isHovered = effectiveHoveredID == segment.item.id
                let dimmed = effectiveHoveredID != nil && !isHovered
                let animatedEnd = segment.startAngle + segment.spanAngle * animationProgress

                DonutSegmentShape(
                    startAngle: Double(segment.startAngle),
                    endAngle: Double(animatedEnd),
                    innerRadius: innerR,
                    outerRadius: outerR,
                    cornerRadius: segment.depth == 0 ? 6 : 3
                )
                .fill(DiskColors.gradient(for: segment.colorIndex, depth: segment.depth))
                .shadow(
                    color: DiskColors.color(for: segment.colorIndex).opacity(isHovered ? 0.35 : 0.12),
                    radius: isHovered ? 10 : 4,
                    y: isHovered ? 2 : 1
                )
                .overlay {
                    DonutSegmentShape(
                        startAngle: Double(segment.startAngle),
                        endAngle: Double(animatedEnd),
                        innerRadius: innerR,
                        outerRadius: outerR,
                        cornerRadius: segment.depth == 0 ? 6 : 3
                    )
                    .stroke(Color.white.opacity(isHovered ? 0.45 : 0.15), lineWidth: isHovered ? 1.5 : 0.75)
                }
                .scaleEffect(isHovered ? 1.02 : 1, anchor: .center)
                .opacity(dimmed ? 0.4 : 1)
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

    private func labelsLayer(chartSize: CGFloat, center: CGPoint) -> some View {
        let depth0 = segments.filter { $0.depth == 0 }
        let depth1 = segments.filter { $0.depth == 1 }

        return ZStack {
            ForEach(depth0) { segment in
                segmentLabel(segment, chartSize: chartSize, center: center, fontSize: 10, minSpan: 14)
            }
            ForEach(depth1) { segment in
                segmentLabel(segment, chartSize: chartSize, center: center, fontSize: 9, minSpan: 10)
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
            let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
            let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
            let radius = segment.depth == 0
                ? outerR + 22
                : (innerR + outerR) / 2
            let angle = (segment.midAngle - 90) * .pi / 180
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            let isHovered = effectiveHoveredID == segment.item.id

            VStack(spacing: 1) {
                Text(segment.item.displayName)
                    .font(.system(size: fontSize, weight: isHovered ? .bold : .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.7)
                if segment.depth == 0 || segment.spanAngle > 16 {
                    Text(segment.item.formattedSize)
                        .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            .padding(.horizontal, segment.depth == 0 ? 6 : 4)
            .padding(.vertical, segment.depth == 0 ? 4 : 2)
            .background {
                if segment.depth == 0 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                }
            }
            .foregroundStyle(segment.depth == 0 ? Color.primary : Color.primary.opacity(0.9))
            .opacity(effectiveHoveredID == nil || isHovered ? 1 : 0.35)
            .position(x: x, y: y)
        }
    }

    private func centerHub(chartSize: CGFloat, center: CGPoint) -> some View {
        let hubSize = chartSize * ChartMetrics.hubRadiusRatio * 1.85

        return ZStack {
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)

            VStack(spacing: 4) {
                Text(centerTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                Text(totalSize > 0 ? ByteFormatter.string(from: totalSize) : "—")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .environment(\.layoutDirection, .leftToRight)
                if let centerSubtitle {
                    Text(centerSubtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Text(L10n.itemsCount(segments.filter { $0.depth == 0 }.count))
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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

    private func hitTest(at point: CGPoint, chartSize: CGFloat, center: CGPoint) -> DiskItem? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx) * 180 / .pi

        for segment in segments.reversed() {
            let innerR = chartSize * SunburstLayoutEngine.innerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
            let outerR = chartSize * SunburstLayoutEngine.outerRadiusRatio(depth: segment.depth, maxDepth: maxDepth)
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
