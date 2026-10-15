// DiskBrowserViewModel+DepthPrefetch.swift — Tiered depth prefetch during and after initial scan.
import Foundation
import LazyDiskCore

extension DiskBrowserViewModel {
    /// After the first screen is ready, prefetch deeper folders for faster drill-down.
    func startBackgroundDepthPrefetch(scanRoot: URL) {
        depthPrefetchTask?.cancel()
        let volumeID = selectedVolume?.id
        let rootEntries = entries
        let displayDepth = initialChartPrefetchMaxDepth
        let deepStart = displayDepth + 1
        let deepEnd = displayDepth + 4
        guard deepStart <= deepEnd else { return }

        depthPrefetchTask = Task.detached(priority: .utility) { [weak self] in
            await self?.prefetchDepthRangeDetached(
                deepStart...deepEnd,
                scanRoot: scanRoot,
                rootEntries: rootEntries,
                volumeID: volumeID,
                trackProgress: false
            )
        }
    }

    func cancelDepthPrefetch() {
        depthPrefetchTask?.cancel()
        depthPrefetchTask = nil
    }

    func prefetchDirectoryIfNeeded(_ url: URL, volumeID: String?) async {
        let folderURL = PathUtils.resolved(url)
        if await cache.has(folderURL) { return }
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
        guard await cache.isComplete(cached) else { return }

        await cache.set(
            folderURL,
            entries: sorted,
            isVolumeRoot: false,
            contentLevel: .light
        )
        await SizeIndexCoordinator.shared.schedulePersist(for: volumeID)
    }

    private func prefetchDepthRange(
        _ range: ClosedRange<Int>,
        scanRoot: URL,
        trackProgress: Bool
    ) async {
        await prefetchDepthRangeDetached(
            range,
            scanRoot: scanRoot,
            rootEntries: entries,
            volumeID: selectedVolume?.id,
            trackProgress: trackProgress
        )
    }

    private func prefetchDepthRangeDetached(
        _ range: ClosedRange<Int>,
        scanRoot: URL,
        rootEntries: [DiskItem],
        volumeID: String?,
        trackProgress: Bool
    ) async {
        var completed = 0
        var total = 0
        for depth in range {
            total += await directoriesAtDepth(depth, scanRoot: scanRoot, rootEntries: rootEntries).count
        }

        for depth in range {
            guard !Task.isCancelled else { return }

            let directories = await directoriesAtDepth(depth, scanRoot: scanRoot, rootEntries: rootEntries)
            for item in directories {
                guard !Task.isCancelled else { return }

                await prefetchDirectoryIfNeeded(item.url, volumeID: volumeID)
                completed += 1

                if trackProgress {
                    let folderName = item.name
                    let done = completed
                    await MainActor.run { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        let prefetchFraction = 0.92 + (Double(done) - 0.6) / Double(max(total, 1)) * 0.08
                        self.scanProgressFraction = max(self.scanProgressFraction, prefetchFraction)
                        self.scanCurrentFolder = folderName
                        self.scanProgress = L10n.scanCachingFolders(done, total)
                    }
                }
            }

            if !trackProgress {
                await MainActor.run { [weak self] in
                    guard let self, self.isInitialChartReady else { return }
                    Task { await self.refreshChartFromScanCache(maxScanDepth: depth) }
                }
            }
        }
    }

    func directoriesAtDepth(
        _ depth: Int,
        scanRoot: URL,
        rootEntries: [DiskItem]
    ) async -> [DiskItem] {
        guard depth >= 1 else { return [] }

        if depth == 1 {
            return ScanDepthPlanner.directories(
                atDepth: 1,
                scanRoot: scanRoot,
                rootEntries: rootEntries,
                childEntries: { _ in nil }
            )
        }

        let parents: [DiskItem]
        if depth == 2 {
            parents = rootEntries.filter { $0.isDirectory && !$0.isVirtual }
        } else {
            parents = await directoriesAtDepth(depth - 1, scanRoot: scanRoot, rootEntries: rootEntries)
        }

        var seen = Set<String>()
        var result: [DiskItem] = []

        for parent in parents {
            guard let cached = await cache.get(parent.url),
                  await cache.isComplete(cached) else { continue }
            for child in cached.entries where child.isDirectory && !child.isVirtual {
                let path = PathUtils.resolved(child.url).path
                if seen.insert(path).inserted {
                    result.append(child)
                }
            }
        }

        return result.sorted { $0.size > $1.size }
    }
}
