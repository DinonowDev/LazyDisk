import SwiftUI
import LazyDiskCore

struct RestrictedScanBannerView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        if !viewModel.restrictedScanEvents.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.restrictedScanBannerTitle)
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.restrictedScanBannerMessage(viewModel.restrictedScanEvents.count))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if let progress = viewModel.privilegedHelperScanProgress, !progress.finished {
                        Text(
                            L10n.scanProgressFmt(
                                Int(progress.filesScanned),
                                Int(max(progress.filesScanned, 1))
                            )
                            + " · "
                            + ByteFormatter.string(from: progress.totalSize)
                        )
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Button(L10n.restrictedScanInstallHelper) {
                            Task { await viewModel.installAdminHelperAndRetryScan() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(viewModel.isInstallingAdminHelper)

                        Button(L10n.restrictedScanRetry) {
                            Task { await viewModel.retryRestrictedScanOnly() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.12))
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
