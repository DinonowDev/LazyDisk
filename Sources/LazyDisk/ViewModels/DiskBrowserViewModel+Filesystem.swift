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
        }

        await applyLightweightFolderRefresh(changedPaths: changedPaths)
    }

    func applyLightweightFolderRefresh(changedPaths: [String]) async {
        guard let currentPath, let volume = selectedVolume else { return }
        let normalized = PathUtils.resolved(currentPath)

        let listed = await scanner.listDirectory(at: normalized)
        let existingByPath = Dictionary(
            uniqueKeysWithValues: entries.map { (PathUtils.resolved($0.url).path, $0) }
        )

        var merged: [DiskItem] = listed.map { item in
            let path = PathUtils.resolved(item.url).path
            if item.isDirectory,
               let existing = existingByPath[path],
               existing.size > 0,
               !existing.isScanning {
                var copy = item
                copy.size = existing.size
                copy.isScanning = false
                return copy
            }
            return item
        }

        merged = sortOrder.sort(merged)

        if isAtVolumeRoot {
            merged = await scanner.reconcileWithVolumeUsage(
                items: merged,
                volume: volume,
                atVolumeRoot: true
            )
        }

        await cache.set(normalized, entries: merged, isVolumeRoot: isAtVolumeRoot, contentLevel: .full)

        let prefs = AppPreferences.load()
        let sizingConfiguration = prefs.sizingConfiguration(fast: true)
        let directoryURLs = merged
            .filter { $0.isDirectory && !$0.isVirtual }
            .map(\.url)

        let walk = await DirectorySizeIndex.shared.rescanSubtree(
            at: normalized,
            listedChildren: directoryURLs,
            configuration: sizingConfiguration
        )
        var updatedEntries = DirectorySizeWalker.applySizes(to: merged, walkResult: walk)

        updatedEntries = sortOrder.sort(updatedEntries)
        if isAtVolumeRoot {
            updatedEntries = await scanner.reconcileWithVolumeUsage(
                items: updatedEntries,
                volume: volume,
                atVolumeRoot: true
            )
        }

        let finalEntries = updatedEntries
        scheduleSizeIndexPersist()
        publishAfterCurrentUpdate { [weak self] in
            self?.entries = finalEntries
            self?.invalidateAllDerivedCaches()
        }
    }

}
