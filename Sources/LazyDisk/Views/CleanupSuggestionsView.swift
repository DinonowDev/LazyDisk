import SwiftUI

struct CleanupSuggestionsView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.cleanupTitle,
                subtitle: viewModel.cleanupSuggestions.isEmpty
                    ? L10n.cleanupEmpty
                    : L10n.suggestionsCount(viewModel.cleanupSuggestions.count)
            )

            SmartCollectionLinkBanner(
                hint: L10n.cleanupCollectionsHint,
                collections: JunkPathCatalog.collections(for: .cleanup)
            )

            if viewModel.isScanningCleanup {
                ScanProgressPanelView.centered(
                    title: viewModel.cleanupProgress?.currentTask ?? L10n.cleanupScan,
                    subtitle: cleanupSubtitle,
                    fraction: viewModel.cleanupProgress?.fraction ?? 0,
                    detail: cleanupDetail,
                    onCancel: { viewModel.cancelCleanupScan() }
                )
            } else if viewModel.cleanupSuggestions.isEmpty {
                emptyState(icon: "sparkles", text: L10n.cleanupEmpty) {
                    Button(L10n.cleanupScan) { viewModel.scanCleanupSuggestions() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.cleanupSuggestions) { suggestion in
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill").foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name).font(.system(size: 13, weight: .semibold))
                                Text(suggestion.reason).font(.system(size: 11)).foregroundStyle(.secondary)
                                Text(suggestion.url.path).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                            Text(ByteFormatter.string(from: suggestion.size))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            CollectorToggleButton(url: suggestion.url, size: 20)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)

                HStack {
                    Button(L10n.cleanupScan) { viewModel.scanCleanupSuggestions() }
                    Spacer()
                    Button(L10n.cleanupAddAll) { viewModel.addAllCleanupSuggestions() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    private var cleanupSubtitle: String? {
        guard let p = viewModel.cleanupProgress else { return nil }
        return L10n.progressStepFmt(p.completed + 1, max(p.total, 1))
    }

    private var cleanupDetail: String? {
        guard let p = viewModel.cleanupProgress, !p.currentTask.isEmpty else { return nil }
        return p.currentTask
    }
}
