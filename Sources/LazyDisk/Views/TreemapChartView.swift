import SwiftUI

struct TreemapChartView: View {
    let items: [DiskItem]
    let totalSize: Int64
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void
    var onAddToCollector: ((DiskItem) -> Void)?

    @State private var animationProgress: CGFloat = 0
    @State private var layoutBounds: CGRect = .zero
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
                    onHover(newID)
                case .ended:
                    isPointerOver = false
                    pointerHoveredID = nil
                    onHover(nil)
                }
            }
            .onAppear {
                layoutBounds = bounds
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { animationProgress = 1 }
            }
            .onChange(of: geometry.size) { _ in
                layoutBounds = bounds
            }
            .onChange(of: items.map(\.id)) { _ in
                animationProgress = 0
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) { animationProgress = 1 }
            }
        }
    }

    private func tilesLayer(in bounds: CGRect) -> some View {
        let rects = TreemapLayoutEngine.layout(items: items, in: bounds, padding: 3)

        return ZStack(alignment: .topLeading) {
            ForEach(rects) { tile in
                let isHovered = effectiveHoveredID == tile.item.id
                let dimmed = effectiveHoveredID != nil && !isHovered
                let animatedRect = scaledRect(tile.rect, progress: animationProgress, in: bounds)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DiskColors.gradient(for: tile.colorIndex))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.5 : 0.2), lineWidth: isHovered ? 2 : 1)

                    if animatedRect.width > 50 && animatedRect.height > 28 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tile.item.displayName)
                                .font(.system(size: 10, weight: isHovered ? .bold : .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.75)
                            Text(tile.item.formattedSize)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .opacity(0.85)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .padding(6)
                    }
                }
                .frame(width: animatedRect.width, height: animatedRect.height)
                .position(x: animatedRect.midX, y: animatedRect.midY)
                .scaleEffect(isHovered ? 1.02 : 1)
                .opacity(dimmed ? 0.45 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovered)
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

    private func scaledRect(_ rect: CGRect, progress: CGFloat, in bounds: CGRect) -> CGRect {
        let w = rect.width * progress
        let h = rect.height * progress
        return CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: max(w, 1), height: max(h, 1))
    }

    private func hitTest(at point: CGPoint, in bounds: CGRect) -> DiskItem? {
        let rects = TreemapLayoutEngine.layout(items: items, in: bounds, padding: 3)
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
