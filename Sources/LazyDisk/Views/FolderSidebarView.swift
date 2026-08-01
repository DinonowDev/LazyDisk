// FolderSidebarView.swift — sidebar shell and search bar wiring.
import SwiftUI
import AppKit

struct FolderSidebarView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

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

            if !viewModel.isAtVolumeRoot {
                breadcrumbSection
            }

            if let volume = viewModel.selectedVolume, viewModel.isAtVolumeRoot, viewModel.activeSmartCollection == nil {
                StorageBreakdownView(volume: volume)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            SmartCollectionsSection()

            if viewModel.activeSmartCollection != nil {
                activeCollectionBanner
            }

            listHeader

            Group {
                if viewModel.isShowingGlobalSearch {
                    GlobalSearchResultsView()
                } else {
                    folderList
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            actionBar
        }
        .background(sidebarBackground)
    }
}
