// DiskBrowserViewModel+Delete.swift — Permanent deletion with safety warnings.
import AppKit
import Foundation
import LazyDiskCore
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Delete

    func requestDelete() {
        let targets = selectedItems.isEmpty ? collectorItems : selectedItems
        let deletable = targets.filter {
            !$0.isVirtual && CleanupService.canDelete(url: $0.url)
        }
        guard !deletable.isEmpty else {
            let hasLibraryContainer = targets.contains { DeletePathAnalyzer.isLibraryContainerPath($0.url) }
            errorMessage = hasLibraryContainer
                ? L10n.errorCannotDeleteLibraryContainer
                : L10n.errorCannotDelete
            return
        }
        pendingDeleteURLs = deletable.map(\.url)
        deleteWarnings = DeleteWarningService.analyze(urls: pendingDeleteURLs)
        showDeleteConfirmation = true
    }

    func confirmDelete() {
        let urls = pendingDeleteURLs.filter { CleanupService.canDelete(url: $0) }
        guard !urls.isEmpty else { return }

        do {
            try CleanupService.deleteItems(urls: urls)
            selectedIDs.removeAll()
            collectorItems.removeAll { item in urls.contains(item.url) }
            pendingDeleteURLs.removeAll()
            deleteWarnings.removeAll()

            if let currentPath {
                Task {
                    await cache.invalidate(currentPath)
                    navigate(to: currentPath)
                }
            }
        } catch {
            errorMessage = L10n.errorDeleteFailed(error.localizedDescription)
        }
    }

    var deleteConfirmationMessage: String {
        let count = pendingDeleteURLs.count
        let totalSize = pendingDeleteURLs.isEmpty ? selectedSize : collectorSize
        return DeleteWarningService.summaryMessage(
            for: deleteWarnings,
            itemCount: count,
            totalSize: totalSize
        )
    }

}
