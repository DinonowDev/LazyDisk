// ScanDiffView+Components.swift — Change rows, stat chips, and reusable UI pieces.
import SwiftUI
import LazyDiskCore

extension ScanDiffView {
    // MARK: - Rows

    func changeRow(_ change: PathChange) -> some View {
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

    func topItemRow(rank: Int, entry: SnapshotEntry) -> some View {
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

    func overviewStat(title: String, value: String, icon: String, tint: Color) -> some View {
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

    func statChip(label: String, count: Int, bytes: Int64, color: Color, icon: String) -> some View {
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

    func filterChip(_ filter: ScanHistoryChangeFilter, count: Int) -> some View {
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

    func miniPill(text: String, icon: String, tint: Color) -> some View {
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

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }

}
