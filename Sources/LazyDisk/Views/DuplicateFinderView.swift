import SwiftUI

struct DuplicateFinderView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.dupTitle,
                subtitle: viewModel.duplicateGroups.isEmpty ? L10n.dupEmpty : L10n.dupGroupsCount(viewModel.duplicateGroups.count)
            )

            if viewModel.isScanningDuplicates {
                duplicateProgressView
            } else if viewModel.duplicateGroups.isEmpty {
                emptyState(icon: "doc.on.doc", text: L10n.dupEmpty) {
                    Button(L10n.dupScan) { viewModel.scanDuplicates() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.duplicateGroups) { group in
                        Section {
                            ForEach(group.files) { file in
                                HStack {
                                    Text(file.url.lastPathComponent).lineLimit(1)
                                    Spacer()
                                    Text(ByteFormatter.string(from: file.size))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Button(L10n.revealFinder) {
                                        NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.system(size: 10))
                                }
                            }
                        } header: {
                            HStack {
                                Text(L10n.dupCopiesCount(group.files.count))
                                Spacer()
                                Text(L10n.dupWaste(ByteFormatter.string(from: group.totalWasted)))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                    }
                }
                .listStyle(.inset)

                HStack {
                    Button(L10n.dupScan) { viewModel.scanDuplicates() }
                    Spacer()
                    Button(L10n.dupDelete) { viewModel.addDuplicateCopiesToCollector() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }

    private var duplicateProgressView: some View {
        ScanProgressPanelView.centered(
            title: progressTitle,
            subtitle: progressSubtitle,
            fraction: viewModel.duplicateProgress?.fraction ?? 0,
            detail: progressDetail,
            onCancel: { viewModel.cancelDuplicateScan() }
        )
    }

    private var progressTitle: String {
        guard let p = viewModel.duplicateProgress else { return L10n.dupScan }
        switch p.phase {
        case .collecting: return L10n.dupPhaseCollect
        case .hashing: return L10n.dupPhaseHash
        case .done: return L10n.dupScan
        }
    }

    private var progressSubtitle: String? {
        guard let p = viewModel.duplicateProgress else { return nil }
        return L10n.scanProgressFmt(p.hashedFiles > 0 ? p.hashedFiles : p.scannedFiles, max(p.candidateFiles, p.scannedFiles, 1))
    }

    private var progressDetail: String? {
        guard let p = viewModel.duplicateProgress, p.groupsFound > 0 else { return nil }
        return L10n.dupGroupsCount(p.groupsFound)
    }
}
