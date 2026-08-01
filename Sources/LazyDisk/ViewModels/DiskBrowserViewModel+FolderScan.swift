// DiskBrowserViewModel+FolderScan.swift — Per-folder scan and background prefetch.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Private

    func performScan(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        trackDetailedProgress: Bool,
        generation: UInt? = nil
    ) async {
        let normalized = PathUtils.resolved(url)

        guard generation == nil || generation == navigationGeneration else { return }

        currentPath = normalized
        isLoading = true

        if trackDetailedProgress {
            scanProgressFraction = 0.05
            scanProgress = L10n.scanReadingList
            scanCurrentFolder = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        }

        let listed = await scanner.listDirectory(at: normalized)
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        entries = listed

        if trackDetailedProgress {
            scanProgressFraction = 0.1
            scanProgress = L10n.scanFoundItems(listed.count)
        }

        let scanned = await scanner.scanDirectorySizes(
            items: listed,
            parallelism: AppPreferences.load().scanParallelism
        ) { [weak self] update in
            DispatchQueue.main.async {
                self?.publishScanProgress(
                    update,
                    trackDetailedProgress: trackDetailedProgress,
                    generation: generation
                )
            }
        }
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        flushDeferredScanSort()
        var sorted = sortOrder.sort(scanned)

        if trackDetailedProgress {
            scanProgressFraction = 0.88
            scanProgress = L10n.scanFinalizing
        }

        if isVolumeRoot, let volume {
            sorted = await scanner.reconcileWithVolumeUsage(
                items: sorted,
                volume: volume,
                atVolumeRoot: true
            )
        }

        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        entries = sorted
        await cache.set(normalized, entries: sorted, isVolumeRoot: isVolumeRoot)

        if trackDetailedProgress {
            scanProgressFraction = 0.92
            scanProgress = L10n.scanCaching
        }
    }

    func startPrefetching(from items: [DiskItem]) {
        prefetchTask?.cancel()
        let directories = items.filter { $0.isDirectory && !$0.isVirtual }
        let parallelism = AppPreferences.load().scanParallelism

        prefetchTask = Task.detached(priority: .utility) { [weak self] in
            let total = directories.count
            for (index, item) in directories.enumerated() {
                guard !Task.isCancelled else { return }

                let folderURL = PathUtils.resolved(item.url)
                if await ScanCache.shared.has(folderURL) { continue }

                let listed = await DiskScanner.shared.listDirectory(at: folderURL)
                guard !Task.isCancelled else { return }

                let scanned = await DiskScanner.shared.scanDirectorySizes(
                    items: listed,
                    parallelism: parallelism
                )
                guard !Task.isCancelled else { return }

                let sorted = scanned.sorted { $0.size > $1.size }
                let cached = CachedDirectory(
                    url: folderURL,
                    entries: sorted,
                    scannedAt: Date(),
                    isVolumeRoot: false
                )
                guard await ScanCache.shared.isComplete(cached) else { continue }

                await ScanCache.shared.set(folderURL, entries: sorted, isVolumeRoot: false)

                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    if self.appPhase == .scanning {
                        let fraction = 0.92 + (Double(index + 1) / Double(max(total, 1))) * 0.08
                        self.scanProgressFraction = fraction
                        self.scanCurrentFolder = item.name
                        self.scanProgress = L10n.scanCachingFolders(index + 1, total)
                    }
                }
            }
        }
    }

}
