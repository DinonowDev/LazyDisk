import SwiftUI

struct SimpleFolderSidebarView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    var hoveredID: UUID?
    var onHover: (UUID?) -> Void
    var chartStyles: [ChartStyle]
    @Binding var chartStyle: ChartStyle

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)

            if !viewModel.isAtVolumeRoot {
                BreadcrumbView(
                    breadcrumbs: viewModel.breadcrumbs,
                    volumeName: viewModel.selectedVolume?.name ?? L10n.diskLabel
                ) { url in
                    viewModel.navigate(to: url)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            folderList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            storageFooter
        }
        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
        .background(sidebarBackground)
    }

    private var sidebarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.primary.opacity(0.02), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if viewModel.isLoading {
                        HStack(spacing: 4) {
                            CompactProgressView(size: 10)
                            Text(viewModel.scanProgress.isEmpty ? L10n.scanLive : viewModel.scanProgress)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                Text(ByteFormatter.string(from: viewModel.displayTotalSize))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .environment(\.layoutDirection, .leftToRight)

                SidebarIconButton(
                    icon: "arrow.up",
                    isEnabled: viewModel.breadcrumbs.count > 1,
                    help: L10n.goUp
                ) {
                    viewModel.navigateUp()
                }
            }

            HStack {
                ChartStylePicker(selection: $chartStyle, styles: chartStyles)
                Spacer()
                simpleToolbar
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var simpleToolbar: some View {
        HStack(spacing: 4) {
            SidebarIconButton(icon: "gearshape", isEnabled: true, help: L10n.preferences) {
                viewModel.showPreferences = true
            }
            SidebarIconButton(
                icon: "arrow.clockwise",
                isEnabled: !viewModel.isLoading,
                help: L10n.rescan
            ) {
                viewModel.rescanVolume()
            }
        }
    }

    private var headerTitle: String {
        if viewModel.isAtVolumeRoot {
            return viewModel.selectedVolume?.name ?? L10n.diskLabel
        }
        guard let path = viewModel.currentPath else { return L10n.diskLabel }
        let name = path.lastPathComponent
        return name.isEmpty ? path.path : name
    }

    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if viewModel.browserListEntries.isEmpty && !viewModel.isLoading {
                    emptyState
                }

                ForEach(Array(viewModel.browserListEntries.enumerated()), id: \.element.id) { index, item in
                    SimpleFolderRow(
                        item: item,
                        color: colorForItem(item, listIndex: index),
                        isHovered: hoveredID == item.id
                    )
                    .contentShape(Rectangle())
                    .draggableItem(item)
                    .onTapGesture(count: 2) {
                        viewModel.handleItemDoubleClick(item)
                    }
                    .onTapGesture {
                        guard !item.isVirtual else { return }
                        if item.isDirectory {
                            viewModel.openItem(item)
                        }
                    }
                    .onHover { hovering in
                        onHover(hovering ? item.id : nil)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text(L10n.emptyFolder)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var storageFooter: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            if let volume = viewModel.selectedVolume {
                footerRow(
                    icon: "circle.fill",
                    iconColor: Color.primary.opacity(0.25),
                    label: L10n.storageFree,
                    value: volume.formattedAvailable
                )
                if volume.purgeableCapacity > 0 {
                    footerRow(
                        icon: "circle",
                        iconColor: Color.secondary.opacity(0.5),
                        label: L10n.purgeableSpace,
                        value: volume.formattedPurgeable
                    )
                }
            }
        }
        .padding(.bottom, 6)
    }

    private func footerRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 7))
                .foregroundStyle(iconColor)
                .frame(width: 10)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private func colorForItem(_ item: DiskItem, listIndex: Int) -> Color {
        if let chartIndex = viewModel.chartItems.firstIndex(where: { $0.id == item.id }) {
            return DiskColors.spectrumColor(
                forChartIndex: chartIndex,
                total: viewModel.chartItems.count
            )
        }
        return DiskColors.color(for: listIndex)
    }
}

private struct SimpleFolderRow: View {
    let item: DiskItem
    let color: Color
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            Text(item.displayName)
                .font(.system(size: 12, weight: isHovered ? .semibold : .regular))
                .foregroundStyle(item.isVirtual ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if item.isScanning {
                CompactProgressView(size: 10)
            } else {
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
    }
}
