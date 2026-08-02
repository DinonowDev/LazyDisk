// DiskBrowserViewModel+IncrementalScan.swift — Incremental folder refresh and cache restore.
import Foundation
import LazyDiskCore
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Cache restore

    func attemptAutoRestoreFromCache() async -> Bool {
        guard AppPreferences.load().usePersistentCache,
              appPhase == .welcome,
              let volume = selectedVolume ?? volumes.first,
              await cache.hasRestorableVolumeRoot(volume.scanRoot) else {
            return false
        }

        selectedVolume = volume
        await restoreSessionFromCache(volume: volume)
        return true
    }

    func restoreSessionFromCache(volume: VolumeInfo) async {
        let session = SessionStateStore.load()
        let scanRoot = volume.scanRoot

        guard let rootCached = await cache.get(scanRoot) else { return }

        await SizeIndexCoordinator.shared.warm(for: volume)

        currentPath = scanRoot
        entries = rootCached.entries
        loadedFromCache = true
        isLoading = false
        scanProgress = L10n.scanFromCache
        scanProgressFraction = 1

        if let pathString = session.lastPath {
            let candidate = URL(fileURLWithPath: pathString, isDirectory: true)
            if PathUtils.isWithinVolume(candidate, scanRoot: scanRoot),
               candidate.path != PathUtils.resolved(scanRoot).path,
               let pathCached = await cache.get(candidate),
               await cache.isComplete(pathCached) {
                currentPath = candidate
                entries = pathCached.entries
            }
        }

        invalidateAllDerivedCaches()
        restartFilesystemMonitoring()
        refreshChartChildrenIfNeeded()
        SessionStateStore.save(volumeID: volume.id, path: currentPath)

        withAnimation(.easeInOut(duration: 0.35)) {
            appPhase = .ready
        }

        startSearchIndexBuild()
        applyPendingExternalAnalyzeIfNeeded()
        startBackgroundIncrementalRefresh(volume: volume)
    }

    func startBackgroundIncrementalRefresh(volume: VolumeInfo) {
        incrementalRefreshTask?.cancel()
        incrementalRefreshTask = Task {
            if let currentPath {
                let normalized = PathUtils.resolved(currentPath)
                let isVolumeRoot = normalized.path == PathUtils.resolved(volume.scanRoot).path
                await performIncrementalScan(
                    at: normalized,
                    volume: volume,
                    isVolumeRoot: isVolumeRoot,
                    trackDetailedProgress: false
                )
            }

            guard !Task.isCancelled else { return }

            if isAtVolumeRoot {
                await prefetchInitialDepthLevels(scanRoot: volume.scanRoot)
                startBackgroundDepthPrefetch(scanRoot: volume.scanRoot)
            }
        }
    }

    // MARK: - Incremental scan

    func performIncrementalScan(
        at url: URL,
        volume: VolumeInfo?,
        isVolumeRoot: Bool,
        trackDetailedProgress: Bool,
        generation: UInt? = nil
    ) async {
        let normalized = PathUtils.resolved(url)

        guard generation == nil || generation == navigationGeneration else { return }

        if trackDetailedProgress {
            scanProgressFraction = 0.05
            scanProgress = L10n.scanIncrementalChecking
            scanCurrentFolder = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        }

        let cached = await cache.get(normalized)
        let listed = await scanner.listDirectory(at: normalized)
        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        let plan = IncrementalScanPlanner.plan(listed: listed, cached: cached?.entries)

        for path in plan.pathsToInvalidate {
            await cache.invalidate(URL(fileURLWithPath: path, isDirectory: true))
            await SizeIndexCoordinator.shared.invalidate(prefix: path, volumeID: volume?.id)
        }

        for directory in plan.directoriesToRescan {
            await cache.invalidate(directory)
            let prefix = PathUtils.resolved(directory).path
            await SizeIndexCoordinator.shared.invalidate(prefix: prefix, volumeID: volume?.id)
        }

        var merged = plan.mergedEntries

        if generation == nil || generation == navigationGeneration {
            currentPath = normalized
            entries = sortOrder.sort(merged)
            invalidateAllDerivedCaches()
            if isVolumeRoot && trackDetailedProgress {
                refreshChartChildrenIfNeeded()
            } else if !isVolumeRoot || !trackDetailedProgress {
                refreshChartChildrenIfNeeded()
            }
        }

        guard plan.needsRescan else {
            if isVolumeRoot, let volume {
                merged = await scanner.reconcileWithVolumeUsage(
                    items: sortOrder.sort(merged),
                    volume: volume,
                    atVolumeRoot: true
                )
            } else {
                merged = sortOrder.sort(merged)
            }

            guard generation == nil || generation == navigationGeneration else { return }

            entries = merged
            await cache.set(
                normalized,
                entries: merged,
                isVolumeRoot: isVolumeRoot,
                contentLevel: .full
            )
            scheduleSizeIndexPersist()

            if trackDetailedProgress {
                scanProgressFraction = 1
                scanProgress = L10n.scanIncrementalUpToDate
            }
            return
        }

        if trackDetailedProgress {
            scanProgressFraction = 0.12
            scanProgress = L10n.scanIncrementalUpdating(plan.directoriesToRescan.count)
        }

        let prefs = AppPreferences.load()
        let directoriesToScan = merged.filter { item in
            item.isDirectory
                && !item.isVirtual
                && plan.directoriesToRescan.contains(where: {
                    PathUtils.resolved($0).path == PathUtils.resolved(item.url).path
                })
        }

        let scanned = await scanner.scanDirectorySizesParallel(
            items: directoriesToScan,
            parallelism: prefs.scanParallelism
        ) { [weak self] update in
            DispatchQueue.main.async {
                self?.publishIncrementalScanProgress(
                    update,
                    merged: merged,
                    trackDetailedProgress: trackDetailedProgress,
                    generation: generation
                )
            }
        }

        guard !Task.isCancelled, generation == nil || generation == navigationGeneration else { return }

        let scannedByPath = Dictionary(
            uniqueKeysWithValues: scanned.map { (PathUtils.resolved($0.url).path, $0) }
        )
        merged = merged.map { item in
            let path = PathUtils.resolved(item.url).path
            return scannedByPath[path] ?? item
        }

        merged = sortOrder.sort(merged)
        if isVolumeRoot, let volume {
            merged = await scanner.reconcileWithVolumeUsage(
                items: merged,
                volume: volume,
                atVolumeRoot: true
            )
        }

        guard generation == nil || generation == navigationGeneration else { return }

        entries = merged
        invalidateAllDerivedCaches()
        refreshChartChildrenIfNeeded()
        await cache.set(
            normalized,
            entries: merged,
            isVolumeRoot: isVolumeRoot,
            contentLevel: .full
        )
        scheduleSizeIndexPersist()

        if trackDetailedProgress {
            scanProgressFraction = 1
            scanProgress = L10n.scanIncrementalDone
        }
    }

    private func publishIncrementalScanProgress(
        _ update: ScanProgressUpdate,
        merged: [DiskItem],
        trackDetailedProgress: Bool,
        generation: UInt?
    ) {
        guard trackDetailedProgress else { return }
        guard generation == nil || generation == navigationGeneration else { return }

        if let partial = update.partialEntries {
            let scannedByPath = Dictionary(
                uniqueKeysWithValues: partial.map { (PathUtils.resolved($0.url).path, $0) }
            )
            entries = sortOrder.sort(
                merged.map { scannedByPath[PathUtils.resolved($0.url).path] ?? $0 }
            )
            invalidateAllDerivedCaches()
        }

        let fraction = 0.12 + (Double(update.completed) / Double(max(update.total, 1))) * 0.86
        scanProgressFraction = max(scanProgressFraction, fraction)
        scanCurrentFolder = update.currentName
        scanProgress = L10n.scanIncrementalFolder(update.completed, update.total, update.currentName)
    }
}
