import SwiftUI

struct ChartLegendView: View {
    let items: [DiskItem]
    let totalSize: Int64
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var onSelect: (DiskItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    LegendChip(
                        name: item.displayName,
                        size: item.formattedSize,
                        percentage: item.percentage(of: totalSize),
                        color: DiskColors.color(for: index),
                        isHovered: hoveredID == item.id,
                        isScanning: item.isScanning
                    )
                    .onTapGesture { onSelect(item) }
                    .onHover { hovering in
                        onHover(hovering ? item.id : nil)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LegendChip: View {
    let name: String
    let size: String
    let percentage: Double
    let color: Color
    let isHovered: Bool
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 10)

            Text(name)
                .font(.system(size: 12, weight: isHovered ? .semibold : .medium))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)

            if !isScanning {
                Text(size)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule(style: .continuous)
                .fill(isHovered ? color.opacity(0.14) : Color.primary.opacity(0.04))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isHovered ? color.opacity(0.35) : Color.clear, lineWidth: 1)
                }
        }
        .scaleEffect(isHovered ? 1.04 : 1)
        .animation(.easeOut(duration: 0.1), value: isHovered)
    }
}
