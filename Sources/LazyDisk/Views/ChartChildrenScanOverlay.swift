import SwiftUI

struct ChartChildrenScanOverlay: View {
    let totalSize: Int64
    let progress: ChartChildrenScanProgress?

    @State private var displayFraction: Double = 0

    private var clampedFraction: Double {
        min(max(displayFraction, 0), 1)
    }

    private var percentText: String {
        L10n.percentFmt(Int((clampedFraction * 100).rounded()))
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(totalSize > 0 ? ByteFormatter.string(from: totalSize) : "—")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .environment(\.layoutDirection, .leftToRight)

            if let progress {
                VStack(spacing: 14) {
                    Text(percentText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                        .animation(nil, value: percentText)

                    scanProgressBar

                    VStack(spacing: 6) {
                        Text(L10n.simpleChartScanRing(progress.currentDepth, progress.maxDepth))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                            .textCase(.uppercase)
                            .tracking(0.6)

                        Text(L10n.simpleChartScanProgress(progress.completedFolders, progress.totalFolders))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))

                        if progress.remainingFolders > 0 {
                            Text(L10n.simpleChartScanRemaining(progress.remainingFolders))
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.42))
                        }

                        if progress.filesScanned > 0 {
                            Text(L10n.simpleChartScanFiles(progress.filesScanned))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.36))
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
                }
                .onAppear {
                    displayFraction = progress.fraction
                }
                .onChange(of: progress.fraction) { newValue in
                    displayFraction = max(displayFraction, newValue)
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
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.10).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
        )
    }

    private var scanProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color.white.opacity(0.62)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * clampedFraction))
            }
        }
        .frame(width: 200, height: 6)
        .animation(.easeOut(duration: 0.35), value: clampedFraction)
    }
}
