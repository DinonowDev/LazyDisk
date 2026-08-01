// ScanDiffView+Helpers.swift — Filtering, formatting, and change classification.
import SwiftUI
import LazyDiskCore

extension ScanDiffView {
    // MARK: - Helpers

    var headerSubtitle: String {
        if viewModel.scanSnapshots.isEmpty { return L10n.historyEmpty }
        return L10n.historySnapshotsCount(viewModel.scanSnapshots.count)
    }

    var compareTitle: String {
        switch viewModel.historyCompareMode {
        case .currentState: return L10n.historyDiff
        case .previousSnapshot: return L10n.historySincePrevious
        }
    }

    func refreshHistoryIfNeeded() {
        viewModel.loadScanHistory(force: viewModel.scanSnapshots.isEmpty)
    }

    func refreshDiff() {
        guard let snapshot = viewModel.selectedScanSnapshot else { return }
        viewModel.updateScanDiff(with: snapshot)
    }

    func timelineDelta(for snapshot: ScanSnapshot, at index: Int) -> Int64? {
        let olderIndex = index + 1
        guard olderIndex < viewModel.scanSnapshots.count else { return nil }
        let older = viewModel.scanSnapshots[olderIndex]
        return ScanHistoryDiff.usageDelta(from: older, to: snapshot)
    }

    func filteredPaths(from diff: ScanDiff) -> [PathChange] {
        let base: [PathChange]
        switch changeFilter {
        case .all:
            base = diff.addedPaths + diff.removedPaths + diff.changedPaths
        case .added: base = diff.addedPaths
        case .removed: base = diff.removedPaths
        case .changed: base = diff.changedPaths
        }
        let sorted = base.sorted { abs($0.delta) > abs($1.delta) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.path.localizedCaseInsensitiveContains(query)
                || ($0.path as NSString).lastPathComponent.localizedCaseInsensitiveContains(query)
        }
    }

    enum ChangeKind {
        case added, removed, changed
        var icon: String {
            switch self {
            case .added: return "plus.square.fill"
            case .removed: return "minus.square.fill"
            case .changed: return "arrow.triangle.2.circlepath.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .added: return .red
            case .removed: return .green
            case .changed: return .orange
            }
        }
    }

    func changeKind(for change: PathChange) -> ChangeKind {
        if change.newSize == nil { return .removed }
        if change.delta == change.newSize { return .added }
        return .changed
    }

    func previousSize(for change: PathChange) -> Int64? {
        guard let newSize = change.newSize else { return nil }
        return newSize - change.delta
    }

    func topItemFraction(_ entry: SnapshotEntry, in snapshot: ScanSnapshot?) -> CGFloat {
        guard let snapshot, let maxSize = snapshot.entries.map(\.size).max(), maxSize > 0 else { return 0 }
        return CGFloat(entry.size) / CGFloat(maxSize)
    }

    func filterLabel(_ filter: ScanHistoryChangeFilter) -> String {
        switch filter {
        case .all: return L10n.historyFilterAll
        case .added: return L10n.historyAdded
        case .removed: return L10n.historyRemoved
        case .changed: return L10n.historyChanged
        }
    }

    func formatSignedDelta(_ delta: Int64) -> String {
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
        return "\(sign)\(ByteFormatter.string(from: abs(delta)))"
    }

}
