import SwiftUI

struct DevModeView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.devTitle,
                subtitle: viewModel.devJunkItems.isEmpty ? L10n.devEmpty : L10n.devFoldersCount(viewModel.devJunkItems.count)
            )

            SmartCollectionLinkBanner(
                hint: L10n.devCollectionsHint,
                collections: JunkPathCatalog.collections(for: .dev)
            )

            if viewModel.isScanningDev {
                ScanProgressPanelView.centered(
                    title: L10n.devScan,
                    subtitle: viewModel.devProgress.map { L10n.scanProgressFmt($0.found, max($0.scannedDirs, 1)) },
                    fraction: viewModel.devProgress?.fraction ?? 0,
                    detail: viewModel.devProgress?.currentPath,
                    onCancel: { viewModel.cancelDevScan() }
                )
            } else if viewModel.devJunkItems.isEmpty {
                emptyState(icon: "chevron.left.forwardslash.chevron.right", text: L10n.devEmpty) {
                    Button(L10n.devScan) { viewModel.scanDevJunk() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.devJunkItems) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill").foregroundStyle(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.system(size: 13, weight: .semibold))
                                Text(item.category).font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(item.url.path).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                            Text(ByteFormatter.string(from: item.size))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Button { viewModel.addDevJunk(item) } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)

                HStack {
                    Button(L10n.devScan) { viewModel.scanDevJunk() }
                    Spacer()
                    Button(L10n.cleanupAddAll) { viewModel.addAllDevJunk() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
}
