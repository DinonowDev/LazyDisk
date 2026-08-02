// DiskBrowserViewModel+FolderScan.swift — Per-folder scan, lazy content, and smart prefetch.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Scan

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
        invalidateAllDerivedCaches()

        if trackDetailedProgress {
            scanProgressFraction = 0.1
            scanProgress = L10n.scanFoundItems(listed.count)
        }

        let scanned = await scanner.scanDirectorySizes(
            items: listed,
            parent: normalized,
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
        invalidateAllDerivedCaches()
        await cache.set(
            normalized,
            entries: sorted,
            isVolumeRoot: isVolumeRoot,
            contentLevel: .full
        )
        scheduleSizeIndexPersist()

        if trackDetailedProgress {
            scanProgressFraction = 0.92
            scanProgress = L10n.scanCaching
        }
    }

    func upgradeContentMetadata(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        generation: UInt
    ) async {
        guard generation == navigationGeneration else { return }

        let upgraded = await scanner.upgradeToFullContent(at: url, existing: entries)
        guard generation == navigationGeneration else { return }

        var sorted = sortOrder.sort(upgraded)
        if isVolumeRoot, let volume {
            sorted = await scanner.reconcileWithVolumeUsage(
                items: sorted,
                volume: volume,
                atVolumeRoot: true
            )
        }

        entries = sorted
        invalidateAllDerivedCaches()
        await cache.set(
            url,
            entries: sorted,
            isVolumeRoot: isVolumeRoot,
            contentLevel: .full
        )
        scheduleSizeIndexPersist()
    }

    func scheduleSizeIndexPersist() {
        let volumeID = selectedVolume?.id
        Task {
            await SizeIndexCoordinator.shared.schedulePersist(for: volumeID)
        }
    }

    func warmSizeIndexForSelectedVolume() {
        guard let volume = selectedVolume else { return }
        Task {
            await SizeIndexCoordinator.shared.warm(for: volume)
        }
    }

    // MARK: - Prefetch

    func startSmartPrefetch(chartMap: [String: [DiskItem]]? = nil) {
        let map = chartMap ?? chartChildMap
        let parents = chartItems.filter { $0.isDirectory && !$0.isVirtual }
        let plan = ChartPrefetchPlanner.plan(
            chartMap: map,
            chartParents: parents,
            siblings: entries
        )
        startPrefetching(directories: plan)
    }

    func startPrefetching(from items: [DiskItem]) {
        let directories = items
            .filter { $0.isDirectory && !$0.isVirtual }
            .sorted { $0.size > $1.size }
        startPrefetching(directories: directories)
    }

    private func startPrefetching(directories: [DiskItem]) {
        prefetchTask?.cancel()
        guard !directories.isEmpty else { return }

        let volumeID = selectedVolume?.id

        prefetchTask = Task.detached(priority: .utility) { [weak viewModel = self] in
            let total = directories.count
            for (index, item) in directories.enumerated() {
                guard !Task.isCancelled else { return }

                let folderURL = PathUtils.resolved(item.url)
                if await ScanCache.shared.has(folderURL) { continue }

                guard !Task.isCancelled else { return }

                let scanned = await DiskScanner.shared.scanFolderContents(at: folderURL, light: true)
                guard !Task.isCancelled else { return }

                let sorted = scanned.sorted { $0.size > $1.size }
                let cached = CachedDirectory(
                    url: folderURL,
                    entries: sorted,
                    scannedAt: Date(),
                    isVolumeRoot: false,
                    contentLevel: .light
                )
                guard await ScanCache.shared.isComplete(cached) else { continue }

                await ScanCache.shared.set(
                    folderURL,
                    entries: sorted,
                    isVolumeRoot: false,
                    contentLevel: .light
                )
                await SizeIndexCoordinator.shared.schedulePersist(for: volumeID)

                let folderName = item.name
                let prefetchIndex = index
                await MainActor.run {
                    guard let viewModel, !Task.isCancelled else { return }
                    if viewModel.appPhase == .scanning {
                        let fraction = 0.92 + (Double(prefetchIndex + 1) / Double(max(total, 1))) * 0.08
                        viewModel.scanProgressFraction = fraction
                        viewModel.scanCurrentFolder = folderName
                        viewModel.scanProgress = L10n.scanCachingFolders(prefetchIndex + 1, total)
                    }
                }
            }
        }
    }
}
