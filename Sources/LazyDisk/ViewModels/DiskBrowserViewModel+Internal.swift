// DiskBrowserViewModel+Internal.swift — Shared publish helpers, caches, and chart child map.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    func publishAfterCurrentUpdate(_ update: @MainActor @escaping () -> Void) {
        Task { @MainActor in
            update()
        }
    }

    func publishScanProgress(
        _ update: ScanProgressUpdate,
        trackDetailedProgress: Bool,
        generation: UInt?
    ) {
        publishAfterCurrentUpdate { [weak self] in
            guard let self else { return }
            guard generation == nil || generation == self.navigationGeneration else { return }

            if trackDetailedProgress {
                let sizing = update.sizingFraction
                self.scanProgressFraction = ScanProgressMath.volumeScanDisplayFraction(
                    phaseBase: 0.1,
                    sizingFraction: sizing,
                    published: self.scanProgressFraction
                )
                self.scanCurrentFolder = update.currentName
                self.scanProgress = L10n.scanFoldersProgress(update.completed, update.total)
            }

            if let partial = update.partialEntries {
                for item in partial where item.isDirectory && !item.isVirtual {
                    let path = PathUtils.resolved(item.url).path
                    self.pendingScanUpdates[path] = (item.size, item.isScanning)
                }
                self.scheduleScanUIBatch(generation: generation)
            } else if let path = update.itemPath {
                let resolved = PathUtils.resolved(URL(fileURLWithPath: path)).path
                let size = update.itemSize ?? self.entries.first(where: {
                    PathUtils.resolved($0.url).path == resolved
                })?.size ?? 0
                self.pendingScanUpdates[resolved] = (size, false)
                self.scheduleScanUIBatch(generation: generation)
            }
        }
    }

    func scheduleScanUIBatch(generation: UInt?) {
        guard scanUIBatchTask == nil else { return }
        scanUIBatchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            defer { self.scanUIBatchTask = nil }
            guard generation == nil || generation == self.navigationGeneration else {
                self.pendingScanUpdates.removeAll()
                return
            }
            self.flushPendingScanUpdates()
        }
    }

    func flushPendingScanUpdates() {
        scanUIBatchTask?.cancel()
        scanUIBatchTask = nil
        guard !pendingScanUpdates.isEmpty else { return }

        objectWillChange.send()
        for (path, update) in pendingScanUpdates {
            guard let index = entries.firstIndex(where: {
                PathUtils.resolved($0.url).path == path
            }) else { continue }
            entries[index].size = update.size
            entries[index].isScanning = update.isScanning
        }
        pendingScanUpdates.removeAll()
        scanProgressNeedsSort = true
        invalidateChartCaches()
        scheduleDeferredScanSort()
    }

    func scheduleDeferredScanSort() {
        guard scanProgressSortTask == nil else { return }
        scanProgressSortTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            defer { self.scanProgressSortTask = nil }
            guard self.scanProgressNeedsSort else { return }
            self.scanProgressNeedsSort = false
            self.entries = self.sortOrder.sort(self.entries)
            self.invalidateChartCaches()
        }
    }

    func flushDeferredScanSort() {
        flushPendingScanUpdates()
        scanProgressSortTask?.cancel()
        scanProgressSortTask = nil
        if scanProgressNeedsSort {
            scanProgressNeedsSort = false
            entries = sortOrder.sort(entries)
            invalidateChartCaches()
        }
    }

    func clearChartChildMap() {
        resetChartLazyScanState()
        publishChartChildMap([:])
        chartChildrenScanProgress = nil
    }

    func publishChartChildMap(_ newMap: [String: [DiskItem]]) {
        guard chartChildMap != newMap else { return }
        publishAfterCurrentUpdate { [weak self] in
            self?.chartChildMap = newMap
            self?.invalidateChartCaches()
        }
    }

    func chartChildren(from entries: [DiskItem]) -> [DiskItem] {
        let limit = interfaceMode == .simple ? 12 : 8
        return Array(
            entries
                .filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
                .sorted { $0.size > $1.size }
                .prefix(limit)
        )
    }

    func invalidateFilterCountsCache() {
        filterCountsRevision &+= 1
    }

    func invalidateChartCaches() {
        chartCacheRevision &+= 1
    }

    func invalidateAllDerivedCaches() {
        invalidateFilterCountsCache()
        invalidateChartCaches()
    }

    func computeFilterCounts() -> [ContentFilter: Int] {
        var counts: [ContentFilter: Int] = [:]
        for filter in ContentFilter.allCases {
            if filter == .all {
                counts[filter] = entries.count
            } else {
                counts[filter] = entries.filter { filter.matches($0) }.count
            }
        }
        return counts
    }

    func computeChartItems() -> [DiskItem] {
        let total = displayTotalSize
        let sorted = browserListEntries
            .filter { $0.size > 0 || $0.isScanning }
            .sorted { $0.size > $1.size }

        var visible: [DiskItem] = []
        var otherSize: Int64 = 0
        var otherCount = 0

        for item in sorted {
            if item.isScanning {
                visible.append(item)
                continue
            }

            let percent = item.percentage(of: total)
            if percent < chartSmallItemThresholdPercent {
                otherSize += item.size
                otherCount += 1
            } else {
                visible.append(item)
            }
        }

        if otherCount > 0 {
            let otherName = otherCount == 1
                ? L10n.filterOther
                : "\(L10n.filterOther) (\(otherCount))"
            visible.append(DiskItem(
                id: Self.chartOtherGroupID,
                url: URL(fileURLWithPath: "/"),
                name: otherName,
                size: otherSize,
                isDirectory: false,
                isVirtual: true
            ))
        }

        return visible.sorted { $0.size > $1.size }
    }
}
