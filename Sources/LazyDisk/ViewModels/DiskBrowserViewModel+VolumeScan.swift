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
            restartFilesystemMonitoring()
        }
    }

    func startInitialScan() {
        guard let volume = selectedVolume else { return }

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

            startPrefetching(from: entries)
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
        appPhase = .scanning
        scanTask?.cancel()
        prefetchTask?.cancel()
        scanTask = Task {
            await cache.clear()
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
            startPrefetching(from: entries)
            startSearchIndexBuild()
            saveScanSnapshot(volume: volume)
            appPhase = .ready
            isLoading = false
            applyPendingExternalAnalyzeIfNeeded()
        }
    }

}
