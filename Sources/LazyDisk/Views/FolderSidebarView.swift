// FolderSidebarView.swift — sidebar shell and search bar wiring.
import SwiftUI
import AppKit

struct FolderSidebarView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @FocusState private var searchFocused: Bool

    private var isShowingDetail: Bool {
        viewModel.isDetailPanelVisible && viewModel.detailItem != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            if viewModel.isDetailPanelVisible || !viewModel.isAtVolumeRoot {
                breadcrumbSection
            }

            if !isShowingDetail {
                SearchBarView(
                    text: $viewModel.searchText,
                    searchScope: $viewModel.searchScope,
                    filterCounts: viewModel.filterCounts,
                    selectedFilter: $viewModel.contentFilter,
                    isIndexing: viewModel.isBuildingSearchIndex,
                    indexStatus: viewModel.searchIndexStatus,
                    onFilterChange: {
                        viewModel.savePreferences()
                        if viewModel.searchScope == .entireVolume, !viewModel.debouncedSearchText.isEmpty {
                            viewModel.performGlobalSearch()
                        }
                    },
                    onScopeChange: { viewModel.setSearchScope($0) },
                    isSearchFocused: $searchFocused
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .onChange(of: searchFocused) { focused in
                    viewModel.setSearchFieldFocused(focused)
                }
                .onChange(of: viewModel.searchText) { _ in viewModel.bindSearchDebounce() }

                SmartCollectionsSection()

                if viewModel.activeSmartCollection != nil {
                    activeCollectionBanner
                }

                listHeader
            }

            Group {
                if isShowingDetail, let item = viewModel.detailItem {
                    FileDetailPanelView(item: item)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else if viewModel.isShowingGlobalSearch {
                    GlobalSearchResultsView()
                } else {
                    folderList
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isDetailPanelVisible)

            if !isShowingDetail {
                actionBar
            }
        }
        .background(sidebarBackground)
    }
}
