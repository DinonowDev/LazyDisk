import Foundation
import CoreGraphics

public struct TreemapRect: Identifiable, Equatable {
    public var id: UUID { item.id }
    public let item: DiskItem
    public let rect: CGRect
    public let colorIndex: Int

    public init(item: DiskItem, rect: CGRect, colorIndex: Int) {
        self.item = item
        self.rect = rect
        self.colorIndex = colorIndex
    }
}

public enum TreemapLayoutEngine {
    public static func layout(
        items: [DiskItem],
        in bounds: CGRect,
        padding: CGFloat = 2
    ) -> [TreemapRect] {
        let visible = items.filter { $0.size > 0 || $0.isScanning }
        guard !visible.isEmpty, bounds.width > 2, bounds.height > 2 else { return [] }

        let inset = bounds.insetBy(dx: padding / 2, dy: padding / 2)
        var rects: [TreemapRect] = []
        layoutSlice(
            items: Array(visible.enumerated()),
            rect: inset,
            horizontal: inset.width >= inset.height,
            output: &rects
        )
        return rects
    }

    private static func layoutSlice(
        items: [(offset: Int, element: DiskItem)],
        rect: CGRect,
        horizontal: Bool,
        output: inout [TreemapRect]
    ) {
        guard !items.isEmpty, rect.width > 1, rect.height > 1 else { return }

        if items.count == 1 {
            output.append(TreemapRect(item: items[0].element, rect: rect, colorIndex: items[0].offset))
            return
        }

        let total = items.reduce(Double(0)) { $0 + max(Double($1.element.size), 1) }
        guard total > 0 else { return }

        var cursor = rect.origin
        var remaining = rect.size
        var index = 0

        while index < items.count {
            let take = min(3, items.count - index)
            let slice = Array(items[index..<(index + take)])
            let sliceTotal = slice.reduce(0.0) { $0 + max(Double($1.element.size), 1) }

            if horizontal {
                let sliceWidth = rect.width * CGFloat(sliceTotal / total)
                var y = cursor.y
                for entry in slice {
                    let h = remaining.height * CGFloat(max(Double(entry.element.size), 1) / sliceTotal)
                    let tile = CGRect(x: cursor.x, y: y, width: max(sliceWidth, 1), height: max(h, 1))
                    output.append(TreemapRect(item: entry.element, rect: tile, colorIndex: entry.offset))
                    y += h
                }
                cursor.x += sliceWidth
                remaining.width -= sliceWidth
            } else {
                let sliceHeight = rect.height * CGFloat(sliceTotal / total)
                var x = cursor.x
                for entry in slice {
                    let w = remaining.width * CGFloat(max(Double(entry.element.size), 1) / sliceTotal)
                    let tile = CGRect(x: x, y: cursor.y, width: max(w, 1), height: max(sliceHeight, 1))
                    output.append(TreemapRect(item: entry.element, rect: tile, colorIndex: entry.offset))
                    x += w
                }
                cursor.y += sliceHeight
                remaining.height -= sliceHeight
            }

            index += take
        }
    }
}
