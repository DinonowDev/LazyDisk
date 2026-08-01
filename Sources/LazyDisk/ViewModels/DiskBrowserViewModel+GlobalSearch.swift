// DiskBrowserViewModel+GlobalSearch.swift — Volume-wide search and index management.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Global Search

    func performGlobalSearch() {
        guard let volume = selectedVolume else { return }
        let query = debouncedSearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            globalSearchResults = []
            isGlobalSearching = false
            return
        }

        globalSearchTask?.cancel()
        isGlobalSearching = true
        globalSearchResults = []

        globalSearchTask = Task {
            let includeHidden = AppPreferences.load().showHiddenFiles
            let (results, engine) = await globalSearch.search(
                query: query,
                volume: volume,
                filter: contentFilter,
                includeHidden: includeHidden
            )

            guard !Task.isCancelled else { return }
            globalSearchResults = results
            globalSearchEngine = engine
            isGlobalSearching = false
        }
    }

    func startSearchIndexBuild() {
        guard let volume = selectedVolume else { return }
        indexBuildTask?.cancel()

        indexBuildTask = Task {
            let hasIndex = await globalSearch.hasIndex(for: volume)
            if hasIndex {
                searchIndexEntryCount = await globalSearch.indexEntryCount(for: volume)
                searchIndexStatus = L10n.searchIndexReady
                return
            }

            isBuildingSearchIndex = true
            searchIndexStatus = L10n.searchIndexing

            await globalSearch.buildIndex(for: volume, includeHidden: AppPreferences.load().showHiddenFiles) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.searchIndexEntryCount = progress.foundEntries
                    self?.searchIndexStatus = "\(progress.foundEntries) files · \(progress.currentPath)"
                }
            }

            guard !Task.isCancelled else { return }
            isBuildingSearchIndex = false
            searchIndexEntryCount = await globalSearch.indexEntryCount(for: volume)
            searchIndexStatus = L10n.searchIndexCount(searchIndexEntryCount)
        }
    }

    func rebuildSearchIndex() {
        guard let volume = selectedVolume else { return }
        indexBuildTask?.cancel()
        Task {
            await globalSearch.invalidateIndex(for: volume)
            searchIndexEntryCount = 0
            startSearchIndexBuild()
        }
    }

    func navigateToSearchResult(_ result: GlobalSearchResult) {
        let parent = URL(fileURLWithPath: result.parentPath, isDirectory: true)
        navigate(to: parent)
    }

    func openSearchResult(_ result: GlobalSearchResult) {
        if result.isDirectory {
            navigate(to: result.url)
        } else {
            NSWorkspace.shared.open(result.url)
        }
    }

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        entries = order.sort(entries)
        savePreferences()
    }

    func toggleSort(for column: SortColumn) {
        setSortOrder(sortOrder.toggled(for: column))
    }

}
