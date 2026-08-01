// ScanDiffView+Detail.swift — Snapshot detail panel, diff hero, and footer.
import SwiftUI
import LazyDiskCore

extension ScanDiffView {
    // MARK: - Detail

    var detailPanel: some View {
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

    var rootWarningBanner: some View {
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

    func snapshotOverview(_ snapshot: ScanSnapshot) -> some View {
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

    var compareModePicker: some View {
        Picker("", selection: $viewModel.historyCompareMode) {
            Text(L10n.historyCompareCurrent).tag(ScanHistoryCompareMode.currentState)
            Text(L10n.historyComparePrevious).tag(ScanHistoryCompareMode.previousSnapshot)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    func diffHero(_ diff: ScanDiff) -> some View {
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

    func changeFilterBar(_ diff: ScanDiff) -> some View {
        HStack(spacing: 6) {
            filterChip(.all, count: diff.totalChangeCount)
            filterChip(.added, count: diff.addedCount)
            filterChip(.removed, count: diff.removedCount)
            filterChip(.changed, count: diff.changedCount)
        }
    }

    var searchField: some View {
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

    func changesSection(_ diff: ScanDiff) -> some View {
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

    func topItemsSection(_ snapshot: ScanSnapshot) -> some View {
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

    var footerBar: some View {
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

}
