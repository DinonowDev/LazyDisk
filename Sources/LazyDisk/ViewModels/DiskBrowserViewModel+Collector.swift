// DiskBrowserViewModel+Collector.swift — Staging area for items pending deletion.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Collector

    func addToCollector(_ item: DiskItem) {
        guard !item.isVirtual else { return }
        guard !CollectorService.contains(collectorItems, url: item.url) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            collectorItems = CollectorService.merge(collectorItems, adding: item)
            isCollectorMinimized = false
            isCollectorExpanded = true
        }
    }

    func isInCollector(url: URL) -> Bool {
        CollectorService.contains(collectorItems, url: url)
    }

    func toggleCollector(url: URL) {
        if isInCollector(url: url) {
            removeFromCollector(url: url)
        } else {
            addToCollector(url: url)
        }
    }

    func removeFromCollector(url: URL) {
        let key = PathUtils.resolved(url).path
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            collectorItems.removeAll { PathUtils.resolved($0.url).path == key }
        }
    }

    func addToCollector(url: URL) {
        let resolved = PathUtils.resolved(url)
        if let item = entries.first(where: { PathUtils.resolved($0.url).path == resolved.path }) {
            addToCollector(item)
            return
        }

        let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey])
        let isDirectory = values?.isDirectory == true
        if values?.isRegularFile == true {
            let size = Int64(values?.fileSize ?? 0)
            addToCollector(DiskItem(url: resolved, size: size, isDirectory: false))
            return
        }

        let provisional = DiskItem(url: resolved, isDirectory: isDirectory, isScanning: true)
        addToCollector(provisional)

        Task {
            let size = await scanner.calculateSize(for: resolved)
            guard let index = collectorItems.firstIndex(where: {
                PathUtils.resolved($0.url).path == resolved.path
            }) else { return }
            collectorItems[index].size = size
            collectorItems[index].isScanning = false
        }
    }

    func removeFromCollector(_ item: DiskItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            collectorItems.removeAll { $0.id == item.id }
        }
    }

    func clearCollector() {
        withAnimation(.easeOut(duration: 0.2)) {
            collectorItems.removeAll()
        }
    }

    func requestCollectorDelete() {
        guard !collectorItems.isEmpty else { return }
        pendingDeleteURLs = collectorItems.map(\.url)
        deleteWarnings = DeleteWarningService.analyze(urls: pendingDeleteURLs)
        showDeleteConfirmation = true
    }

}
