// ScanDiffView+Timeline.swift — Timeline sidebar and usage trend chart.
import SwiftUI
import LazyDiskCore

extension ScanDiffView {
    // MARK: - Empty

    var emptyContent: some View {
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

    var timelineSidebar: some View {
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

    func timelineRow(snapshot: ScanSnapshot, index: Int, isLast: Bool) -> some View {
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

    var usageTrendChart: some View {
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

}
