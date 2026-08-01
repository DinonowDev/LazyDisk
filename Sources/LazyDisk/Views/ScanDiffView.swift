import SwiftUI
import LazyDiskCore

struct ScanDiffView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State private var changeFilter: ScanHistoryChangeFilter = .all
    @State private var searchText = ""

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.historyTitle,
                subtitle: headerSubtitle
            )

            if viewModel.scanSnapshots.isEmpty {
                emptyContent
            } else {
                HSplitView {
                    timelineSidebar
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)

                    detailPanel
                        .frame(minWidth: 380)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { refreshHistoryIfNeeded() }
        .onChange(of: viewModel.activePanel) { panel in
            if panel == .history { refreshHistoryIfNeeded() }
        }
        .onChange(of: viewModel.selectedSnapshotID) { _ in
            changeFilter = .all
            searchText = ""
            refreshDiff()
        }
        .onChange(of: viewModel.historyCompareMode) { _ in refreshDiff() }
        .onChange(of: viewModel.entries) { _ in
            if viewModel.activePanel == .history, viewModel.historyCompareMode == .currentState {
                refreshDiff()
            }
        }
    }

    // MARK: - Empty

    private var emptyContent: some View {
        emptyState(icon: "clock.arrow.circlepath", text: L10n.historyEmpty) {
            VStack(spacing: 10) {
                Text(L10n.historyEmptyDesc)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                HStack(spacing: 10) {
                    Label(L10n.historySaved, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(L10n.historyRescan) { viewModel.rescanVolume() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.historyTimeline)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if viewModel.scanSnapshots.count > 1 {
                usageTrendChart
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.scanSnapshots.enumerated()), id: \.element.id) { index, snapshot in
                        timelineRow(snapshot: snapshot, index: index, isLast: index == viewModel.scanSnapshots.count - 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    private func timelineRow(snapshot: ScanSnapshot, index: Int, isLast: Bool) -> some View {
        let isSelected = viewModel.selectedSnapshotID == snapshot.id
        let delta = timelineDelta(for: snapshot, at: index)

        return Button {
            viewModel.selectedSnapshotID = snapshot.id
            viewModel.updateScanDiff(with: snapshot)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 0) {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: isSelected ? 10 : 8, height: isSelected ? 10 : 8)
                        .overlay {
                            if isSelected {
                                Circle()
                                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 3)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    if !isLast {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 16)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(relativeFormatter.localizedString(for: snapshot.scannedAt, relativeTo: Date()))
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        if index == 0 {
                            Text(L10n.scanLive)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.accentColor))
                        }
                    }

                    Text(snapshot.scannedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 8) {
                        Label(ByteFormatter.string(from: snapshot.totalUsed), systemImage: "internaldrive")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        miniPill(
                            text: "\(snapshot.totalFiles)",
                            icon: "doc.on.doc",
                            tint: .secondary
                        )
                        if let delta {
                            miniPill(
                                text: formatSignedDelta(delta),
                                icon: delta >= 0 ? "arrow.up.right" : "arrow.down.right",
                                tint: delta >= 0 ? .red : .green
                            )
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var usageTrendChart: some View {
        let snapshots = Array(viewModel.scanSnapshots.reversed())
        let values = snapshots.map { Double($0.totalUsed) }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let range = max(maxVal - minVal, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text(L10n.historyUsageTrend)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(snapshots.enumerated()), id: \.element.id) { _, snapshot in
                    let normalized = (Double(snapshot.totalUsed) - minVal) / range
                    let isSelected = viewModel.selectedSnapshotID == snapshot.id
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(8, 36 * normalized + 8))
                }
            }
            .frame(height: 44)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - Detail

    private var detailPanel: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                if let snapshot = viewModel.selectedScanSnapshot {
                    if !viewModel.isAtVolumeRoot, viewModel.historyCompareMode == .currentState {
                        rootWarningBanner
                    }

                    snapshotOverview(snapshot)
                    compareModePicker

                    if let diff = viewModel.currentScanDiff {
                        diffHero(diff)
                        changeFilterBar(diff)
                        searchField
                        changesSection(diff)
                    }

                    topItemsSection(snapshot)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            footerBar
        }
    }

    private var rootWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(L10n.historyRootWarning)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if let volume = viewModel.selectedVolume {
                Button(L10n.goUp) { viewModel.navigate(to: volume.scanRoot) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func snapshotOverview(_ snapshot: ScanSnapshot) -> some View {
        let analytics = SnapshotAnalytics.analyze(snapshot)

        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.historySnapshotDetail)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                overviewStat(
                    title: L10n.overviewUsed,
                    value: ByteFormatter.string(from: snapshot.totalUsed),
                    icon: "chart.pie.fill",
                    tint: .accentColor
                )
                overviewStat(
                    title: L10n.historyTrackedSize,
                    value: ByteFormatter.string(from: analytics.trackedBytes),
                    icon: "externaldrive.fill",
                    tint: .blue
                )
                overviewStat(
                    title: L10n.itemsLabel,
                    value: "\(snapshot.totalFiles)",
                    icon: "folder.fill",
                    tint: .orange
                )
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var compareModePicker: some View {
        Picker("", selection: $viewModel.historyCompareMode) {
            Text(L10n.historyCompareCurrent).tag(ScanHistoryCompareMode.currentState)
            Text(L10n.historyComparePrevious).tag(ScanHistoryCompareMode.previousSnapshot)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func diffHero(_ diff: ScanDiff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(compareTitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(L10n.historyNetDelta)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(formatSignedDelta(diff.netDelta))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(diff.netDelta > 0 ? .red : (diff.netDelta < 0 ? .green : .primary))
            }

            HStack(spacing: 10) {
                statChip(
                    label: L10n.historyAdded,
                    count: diff.addedCount,
                    bytes: diff.addedBytes,
                    color: .red,
                    icon: "plus.circle.fill"
                )
                statChip(
                    label: L10n.historyRemoved,
                    count: diff.removedCount,
                    bytes: diff.removedBytes,
                    color: .green,
                    icon: "minus.circle.fill"
                )
                statChip(
                    label: L10n.historyChanged,
                    count: diff.changedCount,
                    bytes: diff.changedPaths.reduce(0) { $0 + abs($1.delta) },
                    color: .orange,
                    icon: "arrow.triangle.2.circlepath"
                )
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private func changeFilterBar(_ diff: ScanDiff) -> some View {
        HStack(spacing: 6) {
            filterChip(.all, count: diff.totalChangeCount)
            filterChip(.added, count: diff.addedCount)
            filterChip(.removed, count: diff.removedCount)
            filterChip(.changed, count: diff.changedCount)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
            TextField(L10n.historySearchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func changesSection(_ diff: ScanDiff) -> some View {
        let paths = filteredPaths(from: diff)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.historyChangesTitle)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(L10n.historyPathsChanged(paths.count))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if paths.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(L10n.historyNoChanges)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.green.opacity(0.06))
                )
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(paths) { change in
                        changeRow(change)
                    }
                }
            }
        }
    }

    private func topItemsSection(_ snapshot: ScanSnapshot) -> some View {
        let top = SnapshotAnalytics.analyze(snapshot).topEntries

        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.historyTopItems)
                .font(.system(size: 12, weight: .bold))

            LazyVStack(spacing: 6) {
                ForEach(Array(top.enumerated()), id: \.element.path) { rank, entry in
                    topItemRow(rank: rank + 1, entry: entry)
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.rescanVolume()
            } label: {
                Label(L10n.historyRescan, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()

            if let id = viewModel.selectedSnapshotID {
                Button(role: .destructive) {
                    viewModel.deleteScanSnapshot(id: id)
                } label: {
                    Label(L10n.historyDeleteSnapshot, systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Rows

    private func changeRow(_ change: PathChange) -> some View {
        let kind = changeKind(for: change)
        let name = (change.path as NSString).lastPathComponent
        let parent = (change.path as NSString).deletingLastPathComponent

        return HStack(spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 14))
                .foregroundStyle(kind.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? change.path : name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(parent)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                if let newSize = change.newSize, kind == .changed, let previous = previousSize(for: change) {
                    Text("\(ByteFormatter.string(from: previous)) → \(ByteFormatter.string(from: newSize))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Text(formatSignedDelta(change.delta))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(change.delta > 0 ? .red : .green)

            Menu {
                Button(L10n.historyOpenPath) { viewModel.openHistoryPath(change.path) }
                Button(L10n.revealFinder) { viewModel.revealHistoryPath(change.path) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(kind.color.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(kind.color.opacity(0.12), lineWidth: 1)
        )
    }

    private func topItemRow(rank: Int, entry: SnapshotEntry) -> some View {
        let name = (entry.path as NSString).lastPathComponent
        let fraction = topItemFraction(entry, in: viewModel.selectedScanSnapshot)

        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
                .frame(width: 16)

            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(entry.isDirectory ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? entry.path : name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(Color.accentColor.opacity(0.55))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)
            }

            Text(ByteFormatter.string(from: entry.size))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                viewModel.openHistoryPath(entry.path)
            } label: {
                Image(systemName: "arrow.up.right.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(L10n.historyOpenPath)
        }
    }

    // MARK: - Components

    private func overviewStat(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statChip(label: String, count: Int, bytes: Int64, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(ByteFormatter.string(from: bytes))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.07))
        )
    }

    private func filterChip(_ filter: ScanHistoryChangeFilter, count: Int) -> some View {
        let isSelected = changeFilter == filter
        return Button {
            changeFilter = filter
        } label: {
            HStack(spacing: 4) {
                Text(filterLabel(filter))
                    .font(.system(size: 10, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func miniPill(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 7))
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.1)))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private var headerSubtitle: String {
        if viewModel.scanSnapshots.isEmpty { return L10n.historyEmpty }
        return L10n.historySnapshotsCount(viewModel.scanSnapshots.count)
    }

    private var compareTitle: String {
        switch viewModel.historyCompareMode {
        case .currentState: return L10n.historyDiff
        case .previousSnapshot: return L10n.historySincePrevious
        }
    }

    private func refreshHistoryIfNeeded() {
        viewModel.loadScanHistory(force: viewModel.scanSnapshots.isEmpty)
    }

    private func refreshDiff() {
        guard let snapshot = viewModel.selectedScanSnapshot else { return }
        viewModel.updateScanDiff(with: snapshot)
    }

    private func timelineDelta(for snapshot: ScanSnapshot, at index: Int) -> Int64? {
        let olderIndex = index + 1
        guard olderIndex < viewModel.scanSnapshots.count else { return nil }
        let older = viewModel.scanSnapshots[olderIndex]
        return ScanHistoryDiff.usageDelta(from: older, to: snapshot)
    }

    private func filteredPaths(from diff: ScanDiff) -> [PathChange] {
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

    private enum ChangeKind {
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

    private func changeKind(for change: PathChange) -> ChangeKind {
        if change.newSize == nil { return .removed }
        if change.delta == change.newSize { return .added }
        return .changed
    }

    private func previousSize(for change: PathChange) -> Int64? {
        guard let newSize = change.newSize else { return nil }
        return newSize - change.delta
    }

    private func topItemFraction(_ entry: SnapshotEntry, in snapshot: ScanSnapshot?) -> CGFloat {
        guard let snapshot, let maxSize = snapshot.entries.map(\.size).max(), maxSize > 0 else { return 0 }
        return CGFloat(entry.size) / CGFloat(maxSize)
    }

    private func filterLabel(_ filter: ScanHistoryChangeFilter) -> String {
        switch filter {
        case .all: return L10n.historyFilterAll
        case .added: return L10n.historyAdded
        case .removed: return L10n.historyRemoved
        case .changed: return L10n.historyChanged
        }
    }

    private func formatSignedDelta(_ delta: Int64) -> String {
        let sign = delta > 0 ? "+" : (delta < 0 ? "−" : "")
        return "\(sign)\(ByteFormatter.string(from: abs(delta)))"
    }
}
