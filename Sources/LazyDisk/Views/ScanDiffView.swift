import SwiftUI

struct ScanDiffView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.historyTitle,
                subtitle: viewModel.scanSnapshots.isEmpty ? L10n.historyEmpty : "\(viewModel.scanSnapshots.count) snapshots"
            )

            if viewModel.scanSnapshots.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", text: L10n.historyEmpty) {
                    Text(L10n.historySaved).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                HSplitView {
                    List(selection: $viewModel.selectedSnapshotID) {
                        ForEach(viewModel.scanSnapshots) { snapshot in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snapshot.scannedAt, style: .date)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(snapshot.scannedAt, style: .time)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(ByteFormatter.string(from: snapshot.totalUsed))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Text("\(snapshot.totalFiles) \(L10n.itemsLabel)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.quaternary)
                            }
                            .tag(Optional(snapshot.id))
                        }
                    }
                    .frame(minWidth: 180)

                    if let diff = viewModel.currentScanDiff {
                        diffDetail(diff)
                    } else {
                        Text(L10n.historyEmpty)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            if viewModel.scanSnapshots.isEmpty {
                Task { @MainActor in
                    await Task.yield()
                    viewModel.loadScanHistory()
                }
            }
        }
        .onChange(of: viewModel.selectedSnapshotID) { id in
            guard let id, let snapshot = viewModel.scanSnapshots.first(where: { $0.id == id }) else { return }
            Task { @MainActor in
                viewModel.updateScanDiff(with: snapshot)
            }
        }
    }

    @ViewBuilder
    private func diffDetail(_ diff: ScanDiff) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.historyDiff).font(.headline)

            HStack(spacing: 16) {
                diffBadge(label: L10n.historyAdded, value: diff.addedBytes, color: .red)
                diffBadge(label: L10n.historyRemoved, value: diff.removedBytes, color: .green)
            }

            Picker("", selection: .constant(0)) {
                Text(L10n.historyChanged).tag(0)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            pathList(diff.changedPaths)

            if !diff.addedPaths.isEmpty {
                Text(L10n.historyAdded).font(.subheadline.bold())
                pathList(diff.addedPaths)
            }

            if !diff.removedPaths.isEmpty {
                Text(L10n.historyRemoved).font(.subheadline.bold())
                pathList(diff.removedPaths)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func pathList(_ paths: [PathChange]) -> some View {
        List(paths) { change in
            HStack {
                Text((change.path as NSString).lastPathComponent).lineLimit(1)
                Spacer()
                Text(formatDelta(change.delta))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(change.delta > 0 ? .red : .green)
            }
        }
        .frame(minHeight: 120)
    }

    private func diffBadge(label: String, value: Int64, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(color)
            Text(ByteFormatter.string(from: value))
                .font(.system(size: 12, design: .monospaced))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.08)))
    }

    private func formatDelta(_ delta: Int64) -> String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(ByteFormatter.string(from: abs(delta)))"
    }
}
