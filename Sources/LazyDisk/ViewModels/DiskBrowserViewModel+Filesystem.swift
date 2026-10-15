// DiskBrowserViewModel+Filesystem.swift — Live filesystem change monitoring.
import AppKit
import Foundation
import LazyDiskCore
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
        fsMonitor.start(watchPaths: [watchPath], latency: 0.15) { [weak self] changedPaths in
            Task { @MainActor in
                self?.handleFilesystemChange(changedPaths: changedPaths)
            }
        }
    }

    func handleFilesystemChange(changedPaths: [String]) {
        fsRefreshTask?.cancel()
        fsRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
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
            await DirectorySizeIndex.shared.invalidate(prefix: path)
            await cache.invalidate(URL(fileURLWithPath: path, isDirectory: true))
        }

        await applyVisibleDirectoryRefresh()

        guard let volume = selectedVolume else { return }
        let configuration = AppPreferences.load().sizingConfiguration()

        let directoriesToRescan = Set(
            changedPaths.compactMap { path -> URL? in
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                    return URL(fileURLWithPath: path, isDirectory: true).deletingLastPathComponent()
                }
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            .filter { PathUtils.isWithinVolume($0, scanRoot: volume.scanRoot) }
            .map { PathUtils.resolved($0).path }
        )

        for dirPath in directoriesToRescan {
            guard !Task.isCancelled else { return }
            let url = URL(fileURLWithPath: dirPath, isDirectory: true)
            _ = await DirectorySizeIndex.shared.rescanSubtree(
                at: url,
                configuration: configuration
            )
        }

        await applyVisibleDirectoryRefresh()

        let normalized = PathUtils.resolved(currentPath)
        await performIncrementalScan(
            at: normalized,
            volume: volume,
            isVolumeRoot: isAtVolumeRoot,
            trackDetailedProgress: false
        )
    }

    /// Re-reads the open folder and reapplies indexed sizes (fast path for FSEvents).
    func applyVisibleDirectoryRefresh() async {
        guard let currentPath, let volume = selectedVolume else { return }

        let normalized = PathUtils.resolved(currentPath)
        let listed = await scanner.listDirectory(at: normalized)
        var sized = await scanner.itemsWithIndexedSizes(listed, scanRoot: volume.scanRoot)
        sized = sortOrder.sort(sized)

        entries = sized
        invalidateAllDerivedCaches()
        refreshChartChildrenIfNeeded()
    }

}
