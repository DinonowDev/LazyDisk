// Treemap chart view — temporarily not wired into ContentView; kept for re-enable.
import SwiftUI

struct TreemapChartView: View {
    let items: [DiskItem]
    let childrenByParentPath: [String: [DiskItem]]
    let totalSize: Int64
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void
    var onAddToCollector: ((DiskItem) -> Void)?

    @State private var animationProgress: CGFloat = 0
    @State private var isPointerOver = false
    @State private var pointerHoveredID: UUID?

    private var effectiveHoveredID: UUID? {
        isPointerOver ? pointerHoveredID : hoveredID
    }

    var body: some View {
        GeometryReader { geometry in
            let bounds = CGRect(origin: .zero, size: geometry.size)

            ZStack {
                if items.isEmpty {
                    emptyState
                } else {
                    tilesLayer(in: bounds)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        if let item = hitTest(at: value.location, in: bounds) {
                            onSelect(item)
                        }
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isPointerOver = true
                    let newID = hitTest(at: location, in: bounds)?.id
                    guard pointerHoveredID != newID else { return }
                    pointerHoveredID = newID
                    Task { @MainActor in onHover(newID) }
                case .ended:
                    isPointerOver = false
                    pointerHoveredID = nil
                    Task { @MainActor in onHover(nil) }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { animationProgress = 1 }
            }
            .onChange(of: items.map(\.id)) { _ in
                animationProgress = 0
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) { animationProgress = 1 }
            }
            .onChange(of: childrenByParentPath.keys.sorted()) { _ in
                animationProgress = 0
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) { animationProgress = 1 }
            }
        }
    }

    private func layoutRects(in bounds: CGRect) -> [TreemapRect] {
        let fitted = fittedBounds(bounds)
        return TreemapLayoutEngine.layoutHierarchical(
            items: items,
            childrenByParentPath: childrenByParentPath,
            in: fitted,
            padding: 3
        )
    }

    private func fittedBounds(_ bounds: CGRect) -> CGRect {
        let w = bounds.width * ChartMetrics.treemapFillRatio
        let h = bounds.height * ChartMetrics.treemapFillRatio
        return CGRect(
            x: bounds.midX - w / 2,
            y: bounds.midY - h / 2,
            width: w,
            height: h
        )
    }

    private func tilesLayer(in bounds: CGRect) -> some View {
        let rects = layoutRects(in: bounds)

        return ZStack(alignment: .topLeading) {
            ForEach(rects) { tile in
                let isHovered = effectiveHoveredID == tile.item.id
                let dimmed = effectiveHoveredID != nil && !isHovered
                let animatedRect = scaledRect(tile.rect, progress: animationProgress, in: bounds)
                let hasNestedChildren = tile.depth == 0
                    && childrenByParentPath[PathUtils.resolved(tile.item.url).path] != nil
                let showLabel = shouldShowLabel(for: tile, hasNestedChildren: hasNestedChildren)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: tile.depth == 0 ? 6 : 4, style: .continuous)
                        .fill(DiskColors.gradient(for: tile.colorIndex, depth: tile.depth))
                    RoundedRectangle(cornerRadius: tile.depth == 0 ? 6 : 4, style: .continuous)
                        .stroke(
                            Color.white.opacity(isHovered ? 0.55 : (tile.depth == 0 ? 0.22 : 0.35)),
                            lineWidth: isHovered ? 2 : (tile.depth == 0 ? 1 : 0.75)
                        )

                    if showLabel {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tile.item.displayName)
                                .font(.system(size: tile.depth == 0 ? 10 : 9, weight: isHovered ? .bold : .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.75)
                            Text(tile.item.formattedSize)
                                .font(.system(size: tile.depth == 0 ? 9 : 8, weight: .medium, design: .monospaced))
                                .opacity(0.85)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .padding(tile.depth == 0 ? 6 : 4)
                    }
                }
                .frame(width: animatedRect.width, height: animatedRect.height)
                .position(x: animatedRect.midX, y: animatedRect.midY)
                .scaleEffect(isHovered ? 1.02 : 1)
                .opacity(dimmed ? 0.45 : (hasNestedChildren && tile.depth == 0 ? 0.92 : 1))
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .zIndex(Double(tile.depth))
                .onDrag { NSItemProvider(object: tile.item.url as NSURL) }
                .contextMenu {
                    if !tile.item.isVirtual {
                        Button(L10n.addToCollector) { onAddToCollector?(tile.item) }
                        if tile.item.isDirectory { Button(L10n.open) { onSelect(tile.item) } }
                    }
                }
            }
        }
    }

    private func shouldShowLabel(for tile: TreemapRect, hasNestedChildren: Bool) -> Bool {
        let rect = tile.rect
        if tile.depth == 0 {
            return !hasNestedChildren && rect.width > 50 && rect.height > 28
        }
        return rect.width > 36 && rect.height > 22
    }

    private func scaledRect(_ rect: CGRect, progress: CGFloat, in bounds: CGRect) -> CGRect {
        let w = rect.width * progress
        let h = rect.height * progress
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: max(w, 1), height: max(h, 1))
    }

    private func hitTest(at point: CGPoint, in bounds: CGRect) -> DiskItem? {
        let rects = layoutRects(in: bounds)
        for tile in rects.reversed() {
            let r = scaledRect(tile.rect, progress: animationProgress, in: bounds)
            if r.contains(point) { return tile.item }
        }
        return nil
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.split.3x3")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(L10n.chartNoData)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
