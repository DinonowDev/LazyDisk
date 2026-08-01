import SwiftUI

struct RoseChartView: View {
    let items: [DiskItem]
    let totalSize: Int64
    let centerTitle: String
    let centerSubtitle: String?
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void
    var onAddToCollector: ((DiskItem) -> Void)? = nil

    @State private var animationProgress: CGFloat = 0
    @State private var cachedLayouts: [SegmentLayout] = []
    @State private var isPointerOverChart = false
    @State private var pointerHoveredID: UUID?

    private let gapDegrees: CGFloat = 2
    private let hoverAnimation: Animation = .easeOut(duration: 0.1)

    private var effectiveHoveredID: UUID? {
        isPointerOverChart ? pointerHoveredID : hoveredID
    }
    private let innerRadiusRatio: CGFloat = 0.24
    private let outerRadiusRatio: CGFloat = 0.38

    private var layouts: [SegmentLayout] {
        cachedLayouts
    }

    var body: some View {
        GeometryReader { geometry in
            let chartSize = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let innerR = chartSize * innerRadiusRatio
            let outerR = chartSize * outerRadiusRatio

            ZStack {
                if items.isEmpty {
                    emptyState
                } else {
                    segmentsLayer(
                        chartSize: chartSize,
                        center: center,
                        innerR: innerR,
                        outerR: outerR
                    )

                    centerHub(chartSize: chartSize, center: center)

                    labelsLayer(
                        center: center,
                        outerR: outerR,
                        canvasSize: geometry.size
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if let item = hitTest(
                            at: value.location,
                            center: center,
                            innerR: innerR,
                            outerR: outerR
                        ) {
                            onSelect(item)
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isPointerOverChart = true
                    let newID = hitTest(
                        at: location,
                        center: center,
                        innerR: innerR,
                        outerR: outerR
                    )?.id
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
            if cachedLayouts.isEmpty {
                cachedLayouts = buildLayouts()
                withAnimation(.spring(response: 0.85, dampingFraction: 0.78)) {
                    animationProgress = 1
                }
            } else {
                animationProgress = 1
            }
        }
        .onChange(of: items.map(\.id)) { _ in
            cachedLayouts = buildLayouts()
            animationProgress = 0
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                animationProgress = 1
            }
        }
    }

    // MARK: - Layers

    private func segmentsLayer(
        chartSize: CGFloat,
        center: CGPoint,
        innerR: CGFloat,
        outerR: CGFloat
    ) -> some View {
        ZStack {
            ForEach(layouts) { layout in
                let isHovered = effectiveHoveredID == layout.item.id
                let dimmed = effectiveHoveredID != nil && !isHovered
                let animatedEnd = layout.startAngle + (layout.spanAngle * animationProgress)

                DonutSegmentShape(
                    startAngle: Double(layout.startAngle),
                    endAngle: Double(animatedEnd),
                    innerRadius: innerR,
                    outerRadius: outerR,
                    cornerRadius: 8
                )
                .fill(DiskColors.gradient(for: layout.index))
                .shadow(
                    color: DiskColors.color(for: layout.index).opacity(isHovered ? 0.4 : 0.15),
                    radius: isHovered ? 14 : 5,
                    y: isHovered ? 3 : 1
                )
                .overlay {
                    DonutSegmentShape(
                        startAngle: Double(layout.startAngle),
                        endAngle: Double(animatedEnd),
                        innerRadius: innerR,
                        outerRadius: outerR,
                        cornerRadius: 8
                    )
                    .stroke(Color.white.opacity(isHovered ? 0.5 : 0.2), lineWidth: isHovered ? 2 : 1)
                }
                .scaleEffect(isHovered ? 1.03 : 1, anchor: .center)
                .opacity(dimmed ? 0.45 : 1)
                .animation(hoverAnimation, value: isHovered)
                .frame(width: chartSize, height: chartSize)
                .position(center)
                .onDrag {
                    NSItemProvider(object: layout.item.url as NSURL)
                }
                .contextMenu {
                    if !layout.item.isVirtual {
                        Button(L10n.addToCollector) { onAddToCollector?(layout.item) }
                        if layout.item.isDirectory {
                            Button(L10n.open) { onSelect(layout.item) }
                        }
                    }
                }
            }
        }
    }

    private func labelsLayer(
        center: CGPoint,
        outerR: CGFloat,
        canvasSize: CGSize
    ) -> some View {
        let placements = ChartLabelLayoutEngine.place(
            layouts: layouts,
            center: center,
            outerRadius: outerR,
            canvasSize: canvasSize,
            hoveredID: effectiveHoveredID,
            animationProgress: animationProgress
        )

        return ChartLabelsOverlay(
            placements: placements,
            totalSize: totalSize,
            hoveredID: effectiveHoveredID
        )
    }

    private func centerHub(chartSize: CGFloat, center: CGPoint) -> some View {
        let hubSize = chartSize * innerRadiusRatio * 1.85

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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .environment(\.layoutDirection, .leftToRight)

                if let centerSubtitle {
                    Text(centerSubtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Text(L10n.itemsCount(items.count))
                    .font(.system(size: 10))
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
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.chartNoData)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Layout math

    private func buildLayouts() -> [SegmentLayout] {
        let dataTotal = max(items.reduce(Int64(0)) { $0 + $1.size }, 1)
        let count = CGFloat(items.count)
        let available = 360 - count * gapDegrees
        var cursor: CGFloat = -90

        return items.enumerated().map { index, item in
            let fraction = CGFloat(item.size) / CGFloat(dataTotal)
            let span = max(fraction * available, item.size > 0 ? 1.2 : 0)
            let start = cursor
            let end = start + span
            cursor = end + gapDegrees

            return SegmentLayout(
                id: item.id,
                item: item,
                index: index,
                startAngle: start,
                endAngle: end,
                midAngle: start + span / 2,
                spanAngle: span
            )
        }
    }

    private func hitTest(
        at point: CGPoint,
        center: CGPoint,
        innerR: CGFloat,
        outerR: CGFloat
    ) -> DiskItem? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance >= innerR - 4, distance <= outerR + 8 else { return nil }

        let angle = atan2(dy, dx) * 180 / .pi

        for layout in layouts {
            let end = layout.startAngle + layout.spanAngle * animationProgress
            var start = layout.startAngle
            var test = angle

            while start < -180 { start += 360; }
            while test < start - 180 { test += 360 }

            if test >= start && test <= end {
                return layout.item
            }
        }
        return nil
    }
}
