import SwiftUI

struct StorageBreakdownView: View {
    let volume: VolumeInfo

    private var usedFraction: CGFloat {
        guard volume.totalCapacity > 0 else { return 0 }
        return CGFloat(volume.usedCapacity) / CGFloat(volume.totalCapacity)
    }

    private var purgeableFraction: CGFloat {
        guard volume.totalCapacity > 0 else { return 0 }
        return CGFloat(volume.purgeableCapacity) / CGFloat(volume.totalCapacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.storageBreakdown)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: geo.size.width * usedFraction, height: 6)

                    if purgeableFraction > 0 {
                        Capsule()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: geo.size.width * purgeableFraction, height: 6)
                            .offset(x: geo.size.width * max(usedFraction - purgeableFraction, 0))
                    }
                }
            }
            .frame(height: 6)

            HStack(alignment: .center, spacing: 0) {
                legendItem(color: .accentColor, label: L10n.storageUsed, value: volume.formattedUsed)
                Spacer(minLength: 4)
                if volume.purgeableCapacity > 0 {
                    legendItem(color: .green, label: L10n.purgeableSpace, value: volume.formattedPurgeable)
                    Spacer(minLength: 4)
                }
                legendItem(color: Color.primary.opacity(0.25), label: L10n.storageFree, value: volume.formattedAvailable)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
