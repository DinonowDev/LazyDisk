import SwiftUI
import AppKit

struct FileDetailPanelView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    let item: DiskItem

    @State private var createdDate: Date?
    @State private var loadedPath: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                iconSection
                statsSection
                pathSection
                actionsSection
            }
            .padding(16)
        }
        .onAppear { loadMetadata() }
        .onChange(of: item.id) { _ in loadMetadata() }
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
                detailActionButton(
                    title: L10n.detailOpenFolder,
                    icon: "folder.fill",
                    prominent: true,
                    action: { viewModel.openItem(item) }
                )

                detailActionButton(
                    title: L10n.detailShowLargeFiles,
                    icon: "doc.fill.badge.ellipsis",
                    action: { viewModel.showLargeFilesInFolder(item) }
                )
            }

            HStack(spacing: 8) {
                detailActionButton(
                    title: L10n.revealFinder,
                    icon: "folder",
                    action: { viewModel.revealInFinder(item) }
                )

                detailActionButton(
                    title: L10n.quickLook,
                    icon: "eye",
                    action: { QuickLookService.preview(urls: [item.url]) }
                )
            }

            detailActionButton(
                title: L10n.addToCollector,
                icon: "plus.circle.fill",
                action: { viewModel.addToCollector(item) }
            )
            .disabled(item.isVirtual)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func detailActionButton(
        title: String,
        icon: String,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let label = Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)

        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .controlSize(.regular)
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
