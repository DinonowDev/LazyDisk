// DiskBrowserViewModel+VolumeScan.swift — Initial volume scan and rescan orchestration.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Welcome & Initial Scan

    func prepareWelcome() {
        startWorkspaceObserversIfNeeded()
        Task {
            let vols = await scanner.listVolumes()
            volumes = vols

            let session = SessionStateStore.load()
            if let lastID = session.lastVolumeID,
               let restored = vols.first(where: { $0.id == lastID }) {
                selectedVolume = restored
            } else if selectedVolume == nil {
                selectedVolume = vols.first(where: { $0.url.path == "/" }) ?? vols.first
            }

            if let volume = selectedVolume {
                await SizeIndexCoordinator.shared.warm(for: volume)
            }
            restartFilesystemMonitoring()

            if await attemptAutoRestoreFromCache() {
                return
            }
        }
    }

    func startInitialScan() {
        guard let volume = selectedVolume else { return }

        if interfaceMode == .simple {
            chartStyle = .rose
        }

        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        appPhase = .scanning
        scanProgressFraction = 0
        scanCurrentFolder = ""
        scanProgress = L10n.scanPreparing
        entries = []
        selectedIDs.removeAll()
        hoveredID = nil

        scanTask = Task {
            let hasCachedRoot = await cache.hasRestorableVolumeRoot(volume.scanRoot)

            if hasCachedRoot {
                await performIncrementalScan(
                    at: volume.scanRoot,
                    volume: volume,
                    isVolumeRoot: true,
                    trackDetailedProgress: true
                )
            } else {
                await PersistentChartScanProgressStore.shared.clear(volumeID: volume.id)
                await scanner.clearSizeCache()
                await globalSearch.invalidateIndex(for: volume)
                await performScan(
                    at: volume.scanRoot,
                    volume: volume,
                    isVolumeRoot: true,
                    trackDetailedProgress: true
                )
            }

            guard !Task.isCancelled else { return }

            await prefetchInitialDepthLevels(scanRoot: volume.scanRoot)

            guard !Task.isCancelled else { return }

            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)
            SessionStateStore.save(volumeID: volume.id, path: volume.scanRoot)

            withAnimation(.easeInOut(duration: 0.35)) {
                appPhase = .ready
            }
            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
            applyPendingExternalAnalyzeIfNeeded()
            startBackgroundDepthPrefetch(scanRoot: volume.scanRoot)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        scanTask = nil
        isLoading = false
        scanProgress = ""
        scanProgressFraction = 0
        scanCurrentFolder = ""
        appPhase = .welcome
    }

    func rescanVolume() {
        guard let volume = selectedVolume else { return }
        let previousPath = currentPath ?? volume.scanRoot

        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        isLoading = true
        scanProgress = L10n.scanIncrementalChecking
        scanTask = Task {
            await performIncrementalScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true
            )
            guard !Task.isCancelled else { return }

            let resolvedPrevious = PathUtils.resolved(previousPath)
            let resolvedRoot = PathUtils.resolved(volume.scanRoot)
            if resolvedPrevious.path != resolvedRoot.path,
               PathUtils.isWithinVolume(resolvedPrevious, scanRoot: volume.scanRoot) {
                await performIncrementalScan(
                    at: resolvedPrevious,
                    volume: volume,
                    isVolumeRoot: false,
                    trackDetailedProgress: false
                )
            }
            guard !Task.isCancelled else { return }

            await prefetchInitialDepthLevels(scanRoot: volume.scanRoot)

            guard !Task.isCancelled else { return }

            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)
            SessionStateStore.save(volumeID: volume.id, path: currentPath ?? volume.scanRoot)
            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
            applyPendingExternalAnalyzeIfNeeded()
            startBackgroundDepthPrefetch(scanRoot: volume.scanRoot)
        }
    }

}
