// DiskBrowserViewModel+Internal.swift — Shared publish helpers and chart child map.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    func publishAfterCurrentUpdate(_ update: @escaping () -> Void) {
        DispatchQueue.main.async(execute: update)
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
                self.objectWillChange.send()
                self.entries[index].size = update.itemSize ?? self.entries[index].size
                self.entries[index].isScanning = false
                self.scanProgressNeedsSort = true
                self.scheduleDeferredScanSort()
            }
        }
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
        }
    }

    func flushDeferredScanSort() {
        scanProgressSortTask?.cancel()
        scanProgressSortTask = nil
        if scanProgressNeedsSort {
            scanProgressNeedsSort = false
            entries = sortOrder.sort(entries)
        }
    }

    func clearChartChildMap() {
        publishChartChildMap([:])
    }

    func publishChartChildMap(_ newMap: [String: [DiskItem]]) {
        guard chartChildMap != newMap else { return }
        publishAfterCurrentUpdate { [weak self] in
            self?.chartChildMap = newMap
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

}
