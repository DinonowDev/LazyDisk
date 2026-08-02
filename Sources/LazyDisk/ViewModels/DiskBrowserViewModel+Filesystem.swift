// DiskBrowserViewModel+Filesystem.swift — Live filesystem change monitoring.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Live Filesystem Monitoring

    func startWorkspaceObserversIfNeeded() {
        guard workspaceObservers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleVolumeListChange() }
            },
            center.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.handleVolumeListChange() }
            },
        ]
    }

    func handleVolumeListChange() {
        Task {
            let vols = await scanner.listVolumes()
            volumes = vols
            if let current = selectedVolume,
               let updated = vols.first(where: { $0.id == current.id }) {
                selectedVolume = updated
            } else if selectedVolume != nil, !vols.contains(where: { $0.id == selectedVolume?.id }) {
                let next = vols.first(where: { $0.url.path == "/" }) ?? vols.first
                if let next {
                    restoreDevJunkForSelectedVolume(volumeID: next.id)
                } else {
                    devJunkItems = []
                }
                selectedVolume = next
                restartFilesystemMonitoring()
            }
        }
    }

    func restartFilesystemMonitoring() {
        fsMonitor.stop()
        guard let volume = selectedVolume else { return }

        let watchPath = PathUtils.resolved(volume.scanRoot).path
        fsMonitor.start(watchPaths: [watchPath], latency: 0.3) { [weak self] changedPaths in
            Task { @MainActor in
                self?.handleFilesystemChange(changedPaths: changedPaths)
            }
        }
    }

    func handleFilesystemChange(changedPaths: [String]) {
        fsRefreshTask?.cancel()
        fsRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await refreshVolumeStatsAndAffectedEntries(changedPaths: changedPaths)
        }
    }

    func refreshVolumeStatsAndAffectedEntries(changedPaths: [String]) async {
        let vols = await scanner.listVolumes()
        volumes = vols
        if let current = selectedVolume,
           let updated = vols.first(where: { $0.id == current.id }) {
            selectedVolume = updated
        }

        guard appPhase == .ready, let currentPath, !isLoading else { return }

        let current = PathUtils.resolved(currentPath).path
        let affectsCurrentView = changedPaths.contains { path in
            path == current
                || path.hasPrefix(current + "/")
                || current.hasPrefix(path + "/")
                || current.hasPrefix(path)
        }
        guard affectsCurrentView else { return }

        let volumeID = selectedVolume?.id
        for path in changedPaths {
            await SizeIndexCoordinator.shared.invalidate(prefix: path, volumeID: volumeID)
            await cache.invalidate(URL(fileURLWithPath: path, isDirectory: true))
        }

        guard let volume = selectedVolume else { return }
        let normalized = PathUtils.resolved(currentPath)
        await performIncrementalScan(
            at: normalized,
            volume: volume,
            isVolumeRoot: isAtVolumeRoot,
            trackDetailedProgress: false
        )
    }

}
