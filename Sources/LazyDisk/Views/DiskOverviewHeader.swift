import SwiftUI

struct DiskOverviewHeader: View {
    let volume: VolumeInfo?
    let currentTotal: Int64
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 24) {
            if let volume {
                statBlock(title: L10n.overviewVolume, value: volume.name, icon: "internaldrive")

                Divider().frame(height: 32)

                statBlock(
                    title: L10n.overviewUsed,
                    value: volume.formattedUsed,
                    subtitle: L10n.overviewOfSize(volume.formattedTotal),
                    icon: "chart.bar.fill"
                )

                Divider().frame(height: 32)

                statBlock(
                    title: L10n.overviewAvailable,
                    value: volume.formattedAvailable,
                    icon: "externaldrive.badge.checkmark"
                )

                Divider().frame(height: 32)

                statBlock(
                    title: L10n.overviewCurrentFolder,
                    value: ByteFormatter.string(from: currentTotal),
                    subtitle: isLoading ? L10n.scanning : nil,
                    icon: "folder.fill"
                )
            }

            Spacer()

            if let volume {
                usageRing(used: volume.usedCapacity, total: volume.totalCapacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
    }

    private func statBlock(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .secondaryLabelStyle()

                Text(value)
                    .font(.system(size: 14, weight: .semibold))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func usageRing(used: Int64, total: Int64) -> some View {
        let fraction = total > 0 ? Double(used) / Double(total) : 0

        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
                .frame(width: 44, height: 44)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    fraction > 0.85 ? Color.red : Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))

            Text(L10n.percentFmt(Int(fraction * 100)))
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
    }
}
