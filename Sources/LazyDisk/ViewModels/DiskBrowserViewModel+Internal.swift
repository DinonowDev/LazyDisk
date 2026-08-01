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
                self.scanProgressFraction = 0.1 + update.fraction * 0.75
                self.scanCurrentFolder = update.currentName
                self.scanProgress = L10n.scanFoldersProgress(update.completed, update.total)
            }

            if let index = update.itemIndex, index < self.entries.count {
                self.pendingScanUpdates[index] = (
                    update.itemSize ?? self.entries[index].size,
                    false
                )
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
        for (index, update) in pendingScanUpdates {
            guard index < entries.count else { continue }
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
        publishChartChildMap([:])
    }

    func publishChartChildMap(_ newMap: [String: [DiskItem]]) {
        guard chartChildMap != newMap else { return }
        publishAfterCurrentUpdate { [weak self] in
            self?.chartChildMap = newMap
            self?.invalidateChartCaches()
        }
    }

    func chartChildren(from entries: [DiskItem]) -> [DiskItem] {
        Array(
            entries
                .filter { !$0.isVirtual && ($0.size > 0 || $0.isDirectory) }
                .sorted { $0.size > $1.size }
                .prefix(8)
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
