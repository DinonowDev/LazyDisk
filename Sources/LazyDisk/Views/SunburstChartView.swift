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
                    hoverTooltip(chartSize: chartSize, center: center)
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
                let innerR = chartSize * segment.innerRadiusRatio
                let outerR = chartSize * segment.outerRadiusRatio
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
        let color = DiskColors.spectrumColor(
            hue: segment.hue,
            saturation: segment.saturation,
            brightness: segment.brightness,
            isHovered: isHovered
        )
        return AnyShapeStyle(color)
    }

    @ViewBuilder
    private func hoverTooltip(chartSize: CGFloat, center: CGPoint) -> some View {
        if let hoveredID = effectiveHoveredID,
           let segment = segments.first(where: { $0.item.id == hoveredID }) {
            let radius = chartSize * segment.midRadiusRatio
            let angle = (segment.midAngle - 90) * .pi / 180
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)

            VStack(spacing: 2) {
                Text(segment.item.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                Text(segment.item.formattedSize)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDaisyDisk ? Color.white.opacity(0.82) : Color.secondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isDaisyDisk ? Color.black.opacity(0.78) : Color(nsColor: .controlBackgroundColor).opacity(0.95))
                    .shadow(color: .black.opacity(isDaisyDisk ? 0.4 : 0.12), radius: 6, y: 2)
            }
            .foregroundStyle(isDaisyDisk ? .white : .primary)
            .position(x: x, y: y)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(hoverAnimation, value: hoveredID)
        }
    }

    private func centerHub(chartSize: CGFloat, center: CGPoint) -> some View {
        let hubRatio = layoutConfig.hubRadius * (isDaisyDisk ? 1.05 : 1.08)
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
        let hubRadius = chartSize * layoutConfig.hubRadius / 2
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
            let innerR = chartSize * segment.innerRadiusRatio
            let outerR = chartSize * segment.outerRadiusRatio
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
