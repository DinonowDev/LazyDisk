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

        await cache.set(normalized, entries: merged, isVolumeRoot: isAtVolumeRoot)

        let indicesToRecalc = merged.enumerated().compactMap { index, item -> Int? in
            guard item.isDirectory, !item.isVirtual else { return nil }
            let dirPath = PathUtils.resolved(item.url).path
            let affected = changedPaths.contains { changedPath in
                changedPath == dirPath || changedPath.hasPrefix(dirPath + "/")
            }
            return affected ? index : nil
        }

        var updatedEntries = merged
        for index in indicesToRecalc {
            guard index < updatedEntries.count else { continue }
            let url = updatedEntries[index].url
            let size = await scanner.calculateSize(for: url)
            guard let idx = updatedEntries.firstIndex(where: { $0.url == url }) else { continue }
            updatedEntries[idx].size = size
            updatedEntries[idx].isScanning = false
        }

        updatedEntries = sortOrder.sort(updatedEntries)
        if isAtVolumeRoot {
            updatedEntries = await scanner.reconcileWithVolumeUsage(
                items: updatedEntries,
                volume: volume,
                atVolumeRoot: true
            )
        }

        let finalEntries = updatedEntries
        publishAfterCurrentUpdate { [weak self] in
            self?.entries = finalEntries
            self?.invalidateAllDerivedCaches()
        }
    }

}
