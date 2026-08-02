import SwiftUI

struct ChartChildrenScanOverlay: View {
    let totalSize: Int64
    let progress: ChartChildrenScanProgress?

    var body: some View {
        VStack(spacing: 14) {
            Text(totalSize > 0 ? ByteFormatter.string(from: totalSize) : "—")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .environment(\.layoutDirection, .leftToRight)

            if let progress {
                VStack(spacing: 10) {
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(.linear)
                        .tint(.white.opacity(0.85))
                        .frame(width: 200)

                    Text("\(progress.percentComplete)%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(L10n.simpleChartScanProgress(progress.completedFolders, progress.totalFolders))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    if progress.remainingFolders > 0 {
                        Text(L10n.simpleChartScanRemaining(progress.remainingFolders))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    if !progress.currentFolderName.isEmpty {
                        Text(L10n.simpleChartScanCurrent(progress.currentFolderName))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 220)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    CompactProgressView(size: 22)
                    Text(L10n.simpleChartScanning)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.10).opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        )
    }
}
