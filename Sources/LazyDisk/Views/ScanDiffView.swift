// ScanDiffView.swift — scan history panel shell and lifecycle hooks.
import SwiftUI
import LazyDiskCore

struct ScanDiffView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State var changeFilter: ScanHistoryChangeFilter = .all
    @State var searchText = ""

    let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.historyTitle,
                subtitle: headerSubtitle
            )

            if viewModel.scanSnapshots.isEmpty {
                emptyContent
            } else {
                HSplitView {
                    timelineSidebar
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)

                    detailPanel
                        .frame(minWidth: 380)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { refreshHistoryIfNeeded() }
        .onChange(of: viewModel.activePanel) { panel in
            if panel == .history { refreshHistoryIfNeeded() }
        }
        .onChange(of: viewModel.selectedSnapshotID) { _ in
            changeFilter = .all
            searchText = ""
            refreshDiff()
        }
        .onChange(of: viewModel.historyCompareMode) { _ in refreshDiff() }
        .onChange(of: viewModel.entries) { _ in
            if viewModel.activePanel == .history, viewModel.historyCompareMode == .currentState {
                refreshDiff()
            }
        }
    }
}
