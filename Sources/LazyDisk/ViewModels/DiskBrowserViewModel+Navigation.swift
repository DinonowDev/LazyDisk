// DiskBrowserViewModel+Navigation.swift — Folder navigation, smart collections, and selection.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Navigation

    func selectVolume(_ volume: VolumeInfo) {
        pauseSidebarWidthTracking()
        if selectedVolume?.id != volume.id {
            historyLoadedVolumeID = nil
            scanSnapshots = []
            selectedSnapshotID = nil
            currentScanDiff = nil
            restoreDevJunkForSelectedVolume(volumeID: volume.id)
        }
        selectedVolume = volume
        restartFilesystemMonitoring()
        warmSizeIndexForSelectedVolume()
        if appPhase == .ready {
            navigate(to: volume.scanRoot)
        }
    }

    func pickVolume(_ volume: VolumeInfo?) {
        if let volume, selectedVolume?.id != volume.id {
            restoreDevJunkForSelectedVolume(volumeID: volume.id)
        } else if volume == nil {
            devJunkItems = []
        }
        selectedVolume = volume
        restartFilesystemMonitoring()
    }

    func navigate(to url: URL) {
        guard appPhase == .ready else { return }

        pauseSidebarWidthTracking()
        clearSmartCollection()
        let normalized = PathUtils.resolved(url)

        prefetchTask?.cancel()
        scanTask?.cancel()
        navigationGeneration += 1
        let generation = navigationGeneration

        withAnimation(.easeInOut(duration: 0.25)) {
            navigationAnimationID = UUID()
        }

        currentPath = normalized
        selectedIDs.removeAll()
        hoveredID = nil
        detailItem = nil
        isDetailPanelVisible = false
        lastSelectedIndex = nil
        keyboardFocusedIndex = 0
        NavigationHistoryService.recordVisit(normalized)
        recentFolders = NavigationHistoryService.recentFolders()
        SessionStateStore.save(volumeID: selectedVolume?.id, path: normalized)

        scanTask = Task {
            let isVolumeRoot = normalized.path == PathUtils.resolved(selectedVolume?.scanRoot ?? normalized).path

            if let cached = await cache.get(normalized), await cache.isComplete(cached) {
                guard generation == navigationGeneration else { return }
                entries = cached.entries
                invalidateAllDerivedCaches()
                refreshChartChildrenIfNeeded()
                currentPath = normalized
                isLoading = false
                loadedFromCache = true
                scanProgress = L10n.scanFromCache

                startSmartPrefetch()

                if cached.contentLevel == .light {
                    await upgradeContentMetadata(
                        at: normalized,
                        volume: selectedVolume,
                        isVolumeRoot: isVolumeRoot,
                        generation: generation
                    )
                }
                return
            }

            loadedFromCache = false
            isLoading = true
            scanProgress = L10n.scanFolderNamed(normalized.lastPathComponent)

            await performScan(
                at: normalized,
                volume: selectedVolume,
                isVolumeRoot: isVolumeRoot,
                trackDetailedProgress: false,
                generation: generation
            )
            guard !Task.isCancelled, generation == navigationGeneration else { return }
            isLoading = false
            scanProgress = ""

            startSmartPrefetch()
        }
    }

    func refreshCurrentFolder() {
        guard let path = currentPath, let volume = selectedVolume else { return }
        prefetchTask?.cancel()
        Task {
            await performIncrementalScan(
                at: path,
                volume: volume,
                isVolumeRoot: isAtVolumeRoot,
                trackDetailedProgress: false
            )
        }
    }

    func navigateUp() {
        if isDetailPanelVisible {
            closeDetailPanel()
            return
        }

        guard let currentPath, let volume = selectedVolume else { return }
        let parent = PathUtils.resolved(currentPath).deletingLastPathComponent()

        if parent.path == PathUtils.resolved(currentPath).path { return }

        if !PathUtils.isWithinVolume(parent, scanRoot: volume.scanRoot) {
            navigate(to: volume.scanRoot)
        } else {
            navigate(to: parent)
        }
    }

    func openItem(_ item: DiskItem) {
        guard !item.isVirtual else { return }

        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func handleItemClick(_ item: DiskItem, at index: Int, commandHeld: Bool, shiftHeld: Bool) {
        if shiftHeld {
            let anchor = lastSelectedIndex ?? keyboardFocusedIndex
            selectRange(from: anchor, to: index)
            lastSelectedIndex = index
            keyboardFocusedIndex = index
            if selectedIDs.count == 1, let id = selectedIDs.first,
               let selected = browserListEntries.first(where: { $0.id == id }),
               !selected.isDirectory {
                detailItem = selected
                isDetailPanelVisible = true
            }
            return
        }

        if commandHeld {
            toggleSelection(item, at: index)
            return
        }

        if item.isDirectory {
            openItem(item)
        } else {
            selectItemForDetail(item, at: index)
        }
    }

    func handleItemDoubleClick(_ item: DiskItem) {
        openItem(item)
    }

    func selectItemForDetail(_ item: DiskItem, at index: Int? = nil) {
        guard !item.isVirtual else { return }
        pauseSidebarWidthTracking()
        selectedIDs = [item.id]
        detailItem = item
        isDetailPanelVisible = true
        if let index {
            lastSelectedIndex = index
            keyboardFocusedIndex = index
        }
    }

    func closeDetailPanel() {
        detailItem = nil
        isDetailPanelVisible = false
    }

    func showLargeFilesInFolder(_ item: DiskItem) {
        guard item.isDirectory, !item.isVirtual else { return }
        navigate(to: item.url)
        runSmartCollection(.largeFiles, root: item.url)
    }

    // MARK: - Smart Collections

    func runSmartCollection(_ collection: SmartCollection, root: URL? = nil) {
        guard let volume = selectedVolume else { return }
        smartCollectionTask?.cancel()
        activeSmartCollection = collection
        smartCollectionResults = []
        isScanningSmartCollection = true
        smartCollectionProgress = nil
        selectedIDs.removeAll()
        detailItem = nil
        isDetailPanelVisible = false
        keyboardFocusedIndex = 0

        let scanRoot = root ?? volume.scanRoot
        smartCollectionTask = Task {
            let results = await SmartCollectionService.scan(
                collection: collection,
                volumeRoot: volume.scanRoot,
                scanRoot: scanRoot
            ) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.smartCollectionProgress = progress
                }
            }
            guard !Task.isCancelled else { return }
            smartCollectionResults = results
            invalidateChartCaches()
            isScanningSmartCollection = false
            scanProgress = collection.title
        }
    }

    func clearSmartCollection() {
        smartCollectionTask?.cancel()
        activeSmartCollection = nil
        smartCollectionResults = []
        isScanningSmartCollection = false
        smartCollectionProgress = nil
    }

    func openSmartCollectionInBrowser(_ collection: SmartCollection) {
        activePanel = .browser
        runSmartCollection(collection)
    }

    func toggleSelection(_ item: DiskItem, at index: Int? = nil) {
        guard !item.isVirtual else { return }

        if let index {
            lastSelectedIndex = index
        }

        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAll() {
        selectedIDs = Set(browserListEntries.filter { !$0.isVirtual }.map(\.id))
    }

    func selectRange(from start: Int, to end: Int) {
        let lower = min(start, end)
        let upper = max(start, end)
        let items = browserListEntries
        guard lower < items.count else { return }

        for index in lower...min(upper, items.count - 1) {
            let item = items[index]
            if !item.isVirtual {
                selectedIDs.insert(item.id)
            }
        }
    }

}
