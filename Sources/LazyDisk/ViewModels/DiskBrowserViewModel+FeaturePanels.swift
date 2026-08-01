// DiskBrowserViewModel+FeaturePanels.swift — Cleanup, duplicates, history, dev junk, and goal panels.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Feature Panels

    func scanCleanupSuggestions() {
        guard let volume = selectedVolume else { return }
        cleanupTask?.cancel()
        isScanningCleanup = true
        cleanupProgress = nil
        cleanupTask = Task {
            cleanupSuggestions = await CleanupSuggestionService.scan(volumeRoot: volume.scanRoot) { [weak self] progress in
                DispatchQueue.main.async { self?.cleanupProgress = progress }
            }
            guard !Task.isCancelled else { return }
            isScanningCleanup = false
            cleanupProgress = nil
            cleanupTask = nil
        }
    }

    func cancelCleanupScan() {
        cleanupTask?.cancel()
        cleanupTask = nil
        isScanningCleanup = false
        cleanupProgress = nil
    }

    func addCleanupSuggestion(_ suggestion: CleanupSuggestion) {
        addToCollector(url: suggestion.url)
    }

    func addAllCleanupSuggestions() {
        for suggestion in cleanupSuggestions {
            addToCollector(url: suggestion.url)
        }
    }

    func scanDuplicates() {
        guard let volume = selectedVolume else { return }
        duplicateTask?.cancel()
        isScanningDuplicates = true
        duplicateGroups = []
        duplicateProgress = nil
        duplicateTask = Task {
            duplicateGroups = await DuplicateFinderService.findDuplicates(in: volume.scanRoot) { [weak self] progress in
                DispatchQueue.main.async { self?.duplicateProgress = progress }
            }
            guard !Task.isCancelled else { return }
            isScanningDuplicates = false
            duplicateProgress = nil
            duplicateTask = nil
        }
    }

    func cancelDuplicateScan() {
        duplicateTask?.cancel()
        duplicateTask = nil
        isScanningDuplicates = false
        duplicateProgress = nil
    }

    func addDuplicateCopiesToCollector() {
        for group in duplicateGroups {
            for file in group.files.dropFirst() {
                addToCollector(url: file.url)
            }
        }
    }

    func loadScanHistory(force: Bool = false) {
        guard let volume = selectedVolume else { return }
        if !force && historyLoadedVolumeID == volume.id { return }
        historyLoadedVolumeID = volume.id
        Task {
            let snapshots = await historyStore.snapshots(for: volume.id)
            let first = snapshots.first
            publishAfterCurrentUpdate { [weak self] in
                guard let self else { return }
                self.scanSnapshots = snapshots
                if let first {
                    self.selectedSnapshotID = first.id
                    self.currentScanDiff = self.computeScanDiff(for: first)
                } else {
                    self.selectedSnapshotID = nil
                    self.currentScanDiff = nil
                }
            }
        }
    }

    var selectedScanSnapshot: ScanSnapshot? {
        guard let selectedSnapshotID else { return nil }
        return scanSnapshots.first { $0.id == selectedSnapshotID }
    }

    func previousScanSnapshot(before snapshot: ScanSnapshot) -> ScanSnapshot? {
        guard let index = scanSnapshots.firstIndex(where: { $0.id == snapshot.id }) else { return nil }
        let olderIndex = index + 1
        guard olderIndex < scanSnapshots.count else { return nil }
        return scanSnapshots[olderIndex]
    }

    func computeScanDiff(for snapshot: ScanSnapshot) -> ScanDiff {
        switch historyCompareMode {
        case .currentState:
            return ScanHistoryDiff.computeDiff(current: entries, previous: snapshot)
        case .previousSnapshot:
            if let previous = previousScanSnapshot(before: snapshot) {
                return ScanHistoryDiff.computeDiff(baseline: previous, target: snapshot)
            }
            return ScanHistoryDiff.computeDiff(current: entries, previous: snapshot)
        }
    }

    func updateScanDiff(with snapshot: ScanSnapshot) {
        let diff = computeScanDiff(for: snapshot)
        publishAfterCurrentUpdate { [weak self] in
            self?.currentScanDiff = diff
        }
    }

    func refreshScanDiff() {
        guard let snapshot = selectedScanSnapshot else { return }
        updateScanDiff(with: snapshot)
    }

    func deleteScanSnapshot(id: UUID) {
        guard let volume = selectedVolume else { return }
        Task {
            await historyStore.deleteSnapshot(volumeID: volume.id, snapshotID: id)
            loadScanHistory(force: true)
        }
    }

    func openHistoryPath(_ path: String) {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        activePanel = .browser
        NSApp.activate(ignoringOtherApps: true)
        navigate(to: url)
    }

    func revealHistoryPath(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func saveScanSnapshot(volume: VolumeInfo) {
        Task {
            await historyStore.saveSnapshot(
                volumeID: volume.id,
                totalUsed: volume.usedCapacity,
                entries: entries
            )
            loadScanHistory(force: true)
        }
    }

    func scanDevJunk() {
        guard let volume = selectedVolume else { return }
        devTask?.cancel()
        isScanningDev = true
        devProgress = nil
        let roots = [volume.scanRoot]
        let volumeID = volume.id
        devTask = Task {
            let results = await DevModeService.scan(roots: roots) { [weak self] progress in
                DispatchQueue.main.async { self?.devProgress = progress }
            }
            guard !Task.isCancelled else { return }
            devJunkCache[volumeID] = results
            if selectedVolume?.id == volumeID {
                devJunkItems = results
            }
            isScanningDev = false
            devProgress = nil
            devTask = nil
        }
    }

    func restoreDevJunkForSelectedVolume(volumeID: String? = nil) {
        let id = volumeID ?? selectedVolume?.id
        devJunkItems = id.flatMap { devJunkCache[$0] } ?? []
    }

    func syncDevJunkDisplay() {
        restoreDevJunkForSelectedVolume()
    }

    func cancelDevScan() {
        devTask?.cancel()
        devTask = nil
        isScanningDev = false
        devProgress = nil
    }

    func addDevJunk(_ item: DevJunkItem) {
        toggleCollector(url: item.url)
    }

    func addAllDevJunk() {
        for item in devJunkItems {
            addToCollector(url: item.url)
        }
    }

    func saveFreeSpaceGoal() {
        var prefs = AppPreferences.load()
        prefs.freeSpaceGoalGB = freeSpaceGoalGB
        prefs.save()
    }

    var goalTargetBytes: Int64 {
        Int64(freeSpaceGoalGB * 1_073_741_824)
    }

    var goalNeededBytes: Int64 {
        guard selectedVolume != nil else { return 0 }
        return max(0, goalTargetBytes - projectedFreeSpace)
    }

    var goalSuggestionsTotalSize: Int64 {
        goalSuggestions.reduce(0) { $0 + $1.size }
    }

    func suggestItemsForGoal() {
        guard let volume = selectedVolume else { return }
        let needed = goalNeededBytes
        guard needed > 0 else {
            goalSuggestions = []
            return
        }

        goalTask?.cancel()
        isScanningGoal = true
        goalScanProgress = nil
        let excludePaths = Set(collectorItems.map { PathUtils.resolved($0.url).path })

        goalTask = Task {
            let suggestions = await GoalSuggestionService.scan(
                volumeRoot: volume.scanRoot,
                neededBytes: needed,
                excludePaths: excludePaths
            ) { [weak self] progress in
                DispatchQueue.main.async { self?.goalScanProgress = progress }
            }
            guard !Task.isCancelled else { return }
            goalSuggestions = suggestions
            isScanningGoal = false
            goalScanProgress = nil
            goalTask = nil
        }
    }

    func cancelGoalScan() {
        goalTask?.cancel()
        goalTask = nil
        isScanningGoal = false
        goalScanProgress = nil
    }

    func addGoalSuggestion(_ suggestion: GoalSuggestion) {
        addToCollector(url: suggestion.url)
    }

    func addAllGoalSuggestions() {
        for suggestion in goalSuggestions where !isInCollector(url: suggestion.url) {
            addToCollector(url: suggestion.url)
        }
    }

    func toggleBookmark() {
        guard let path = currentPath else { return }
        if NavigationHistoryService.isBookmarked(path) {
            if let bm = bookmarks.first(where: { $0.url.path == PathUtils.resolved(path).path }) {
                NavigationHistoryService.removeBookmark(bm)
            }
        } else {
            NavigationHistoryService.addBookmark(path)
        }
        bookmarks = NavigationHistoryService.bookmarks()
    }

    func exportCurrentFolderCSV() {
        guard let url = ExportService.savePanel(format: "csv", defaultName: "lazydisk-export.csv") else { return }
        do {
            try ExportService.exportCSV(entries: browserListEntries, to: url)
            exportMessage = L10n.exportDone
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCurrentFolderJSON() {
        guard let url = ExportService.savePanel(format: "json", defaultName: "lazydisk-export.json") else { return }
        do {
            try ExportService.exportJSON(entries: browserListEntries, to: url)
            exportMessage = L10n.exportDone
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshLanguage() {
        languageRevision += 1
    }

}
