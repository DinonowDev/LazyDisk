import SwiftUI

struct DeleteConfirmationSheet: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @Environment(\.dismiss) private var dismiss

    private var itemCount: Int { viewModel.pendingDeleteURLs.count }
    private var totalSize: Int64 {
        viewModel.pendingDeleteURLs.isEmpty ? viewModel.selectedSize : viewModel.collectorSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 16)

            if viewModel.deleteWarnings.isEmpty {
                safeDeleteBody
            } else {
                warningBody
            }

            Divider().padding(.vertical, 16)
            footer
        }
        .padding(24)
        .frame(width: 480)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.deleteTitle)
                    .font(.system(size: 17, weight: .bold))
                Text(L10n.deleteSubtitle(count: itemCount, size: ByteFormatter.string(from: totalSize)))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var safeDeleteBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.deleteSafeMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            itemPreviewList
        }
    }

    private var warningBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(viewModel.deleteWarnings) { warning in
                WarningRow(warning: warning)
            }
            itemPreviewList
        }
    }

    private var itemPreviewList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.deleteItemsHeader)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(previewItems) { item in
                        HStack(spacing: 8) {
                            FileIconView(url: item.url, size: 16)
                            Text(item.displayName)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            Text(item.formattedSize)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    private var previewItems: [DiskItem] {
        let urls = Set(viewModel.pendingDeleteURLs.map { PathUtils.resolved($0).path })
        let fromCollector = viewModel.collectorItems.filter { urls.contains(PathUtils.resolved($0.url).path) }
        let fromSelection = viewModel.selectedItems.filter { urls.contains(PathUtils.resolved($0.url).path) }
        let combined = fromCollector + fromSelection
        if !combined.isEmpty { return Array(combined.prefix(8)) }
        return viewModel.pendingDeleteURLs.prefix(8).map {
            DiskItem(url: $0, isDirectory: $0.hasDirectoryPath)
        }
    }

    private var footer: some View {
        HStack {
            Button(L10n.cancel) {
                viewModel.pendingDeleteURLs.removeAll()
                viewModel.deleteWarnings.removeAll()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                viewModel.confirmDelete()
                dismiss()
            } label: {
                Label(L10n.deleteAction, systemImage: "trash.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.defaultAction)
        }
    }
}

private struct WarningRow: View {
    let warning: DeleteWarning

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(warning.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(warning.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor.opacity(0.08))
        )
    }

    private var iconName: String {
        switch warning.severity {
        case .danger: return "exclamationmark.octagon.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch warning.severity {
        case .danger: return .red
        case .caution: return .orange
        case .info: return .blue
        }
    }
}
