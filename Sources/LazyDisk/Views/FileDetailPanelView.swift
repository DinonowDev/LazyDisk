import SwiftUI
import AppKit

struct FileDetailPanelView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    let item: DiskItem

    @State private var createdDate: Date?
    @State private var loadedPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    iconSection
                    statsSection
                    pathSection
                    actionsSection
                }
                .padding(16)
            }
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onAppear { loadMetadata() }
        .onChange(of: item.id) { _ in loadMetadata() }
    }

    private var header: some View {
        HStack {
            Text(L10n.detailTitle)
                .font(.system(size: 12, weight: .bold))
            Spacer()
            Button {
                viewModel.isDetailPanelVisible = false
                viewModel.detailItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help(L10n.cancel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var iconSection: some View {
        HStack(spacing: 12) {
            FileIconView(url: item.url, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                Text(item.fileKind.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsSection: some View {
        VStack(spacing: 10) {
            detailRow(label: L10n.columnSize, value: item.formattedSize, mono: true)
            if item.isDirectory {
                detailRow(
                    label: L10n.detailItemCount,
                    value: L10n.itemsCount(childCount),
                    mono: false
                )
            }
            detailRow(label: L10n.columnModified, value: item.formattedModifiedDate)
            detailRow(label: L10n.detailCreated, value: formattedCreated)
            if viewModel.selectedVolume != nil, item.size > 0 {
                detailRow(
                    label: L10n.columnKind,
                    value: String(format: "%.1f%%", item.percentage(of: viewModel.displayTotalSize)),
                    mono: true
                )
            }
        }
    }

    private var pathSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.detailPath)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(loadedPath.isEmpty ? item.url.path : loadedPath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            if item.isDirectory && !item.isVirtual {
                Button { viewModel.openItem(item) } label: {
                    Label(L10n.detailOpenFolder, systemImage: "folder.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button { viewModel.showLargeFilesInFolder(item) } label: {
                    Label(L10n.detailShowLargeFiles, systemImage: "doc.fill.badge.ellipsis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Button { viewModel.revealInFinder(item) } label: {
                    Label(L10n.revealFinder, systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button { QuickLookService.preview(urls: [item.url]) } label: {
                    Label(L10n.quickLook, systemImage: "eye")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button { viewModel.addToCollector(item) } label: {
                Label(L10n.addToCollector, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(item.isVirtual)
        }
    }

    private func detailRow(label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: mono ? .monospaced : .default))
        }
    }

    private var formattedCreated: String {
        guard let createdDate else { return "—" }
        return FileDetailPanelView.dateFormatter.string(from: createdDate)
    }

    private var childCount: Int {
        viewModel.entries.filter {
            PathUtils.isWithinVolume($0.url, scanRoot: item.url) &&
            $0.url.deletingLastPathComponent().path == item.url.path
        }.count
    }

    private func loadMetadata() {
        loadedPath = item.url.path
        if let values = try? item.url.resourceValues(forKeys: [.creationDateKey, .canonicalPathKey]) {
            createdDate = values.creationDate
            if let canonical = values.canonicalPath { loadedPath = canonical }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
