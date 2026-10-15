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
        deleteWarnings = DeleteWarningService.analyze(
            urls: pendingDeleteURLs,
            volumePurgeableBytes: selectedVolume?.purgeableCapacity,
            volumeTotalBytes: selectedVolume?.totalCapacity
        )
        showDeleteConfirmation = true
    }

    func confirmDelete(emptyTrashAfterward: Bool = false) {
        let urls = pendingDeleteURLs.filter { CleanupService.canDelete(url: $0) }
        guard !urls.isEmpty else { return }

        do {
            let result = try CleanupService.deleteItems(urls: urls)
            if emptyTrashAfterward || (urls.count > 1 && AppPreferences.load().emptyTrashAfterBulkDelete) {
                try? TrashService.removeTrashedItems(at: result.trashedItemURLs)
            }

            let removed = Set(result.succeeded)
            selectedIDs.removeAll()
            collectorItems.removeAll { item in removed.contains(item.url) }
            pendingDeleteURLs.removeAll()
            deleteWarnings.removeAll()

            if let currentPath {
                Task {
                    await cache.invalidate(currentPath)
                    await DirectorySizeIndex.shared.invalidate(prefix: PathUtils.resolved(currentPath).path)
                    if let volume = selectedVolume {
                        await VolumeTreeScanCoordinator.shared.clear(volumeID: volume.id)
                    }
                    navigate(to: currentPath)
                }
            }
        } catch {
            errorMessage = L10n.errorDeleteFailed(error.localizedDescription)
        }
    }

    var pendingDeleteTotalSize: Int64 {
        let urls = pendingDeleteURLs
        guard !urls.isEmpty else { return selectedSize }
        return urls.reduce(0) { partial, url in
            partial + sizeForDeleteCandidate(url)
        }
    }

    var deleteConfirmationMessage: String {
        DeleteWarningService.summaryMessage(
            for: deleteWarnings,
            itemCount: pendingDeleteURLs.count,
            totalSize: pendingDeleteTotalSize
        )
    }

    private func sizeForDeleteCandidate(_ url: URL) -> Int64 {
        if let item = entries.first(where: { $0.url == url })
            ?? collectorItems.first(where: { $0.url == url }) {
            return item.size
        }
        let values = try? url.resourceValues(forKeys: [
            .totalFileAllocatedSizeKey,
            .fileSizeKey
        ])
        return Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
    }
}
