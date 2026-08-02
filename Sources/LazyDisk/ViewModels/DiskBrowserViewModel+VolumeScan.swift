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
            if selectedVolume == nil {
                selectedVolume = vols.first(where: { $0.url.path == "/" }) ?? vols.first
            }
            if let volume = selectedVolume {
                await SizeIndexCoordinator.shared.warm(for: volume)
            }
            restartFilesystemMonitoring()
        }
    }

    func startInitialScan() {
        guard let volume = selectedVolume else { return }

        if interfaceMode == .simple {
            chartStyle = .rose
        }

        scanTask?.cancel()
        prefetchTask?.cancel()
        appPhase = .scanning
        scanProgressFraction = 0
        scanCurrentFolder = ""
        scanProgress = L10n.scanPreparing
        entries = []
        selectedIDs.removeAll()
        hoveredID = nil

        scanTask = Task {
            await cache.clear()
            await SizeIndexCoordinator.shared.clear(volumeID: volume.id)
            await PersistentChartScanProgressStore.shared.clear(volumeID: volume.id)
            await scanner.clearSizeCache()
            if let volume = selectedVolume {
                await globalSearch.invalidateIndex(for: volume)
            }
            await performScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true
            )

            guard !Task.isCancelled else { return }

            await prefetchSidebarFirstLevel(volume: volume)
            startSmartPrefetch()
            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)

            withAnimation(.easeInOut(duration: 0.35)) {
                appPhase = .ready
            }
            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
            applyPendingExternalAnalyzeIfNeeded()
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        prefetchTask?.cancel()
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
        isLoading = true
        scanProgress = L10n.scanPreparing
        scanTask = Task {
            await cache.clear()
            await SizeIndexCoordinator.shared.clear(volumeID: volume.id)
            await PersistentChartScanProgressStore.shared.clear(volumeID: volume.id)
            await scanner.clearSizeCache()
            if let volume = selectedVolume {
                await globalSearch.invalidateIndex(for: volume)
            }
            await performScan(
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
                await performScan(
                    at: resolvedPrevious,
                    volume: volume,
                    isVolumeRoot: false,
                    trackDetailedProgress: false
                )
            }
            guard !Task.isCancelled else { return }

            startSmartPrefetch()
            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)
            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
            applyPendingExternalAnalyzeIfNeeded()
        }
    }

}
