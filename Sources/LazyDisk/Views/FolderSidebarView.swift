import SwiftUI
import AppKit

private enum FileListColumns {
    static let spacing: CGFloat = 10
    static let iconWidth: CGFloat = 32
    static let sizeWidth: CGFloat = 68
    static let modifiedWidth: CGFloat = 58
    static let chevronWidth: CGFloat = 12
    static let listPadding: CGFloat = 10
    static let rowPadding: CGFloat = 10
    static var horizontalInset: CGFloat { listPadding + rowPadding }
}

struct FolderSidebarView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            SearchBarView(
                text: $viewModel.searchText,
                searchScope: $viewModel.searchScope,
                filterCounts: viewModel.filterCounts,
                selectedFilter: $viewModel.contentFilter,
                isIndexing: viewModel.isBuildingSearchIndex,
                indexStatus: viewModel.searchIndexStatus,
                onFilterChange: {
                    viewModel.savePreferences()
                    if viewModel.searchScope == .entireVolume, !viewModel.debouncedSearchText.isEmpty {
                        viewModel.performGlobalSearch()
                    }
                },
                onScopeChange: { viewModel.setSearchScope($0) },
                isSearchFocused: $searchFocused
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .onChange(of: searchFocused) { focused in
                viewModel.setSearchFieldFocused(focused)
            }
            .onChange(of: viewModel.searchText) { _ in viewModel.bindSearchDebounce() }

            if !viewModel.isAtVolumeRoot {
                breadcrumbSection
            }

            if let volume = viewModel.selectedVolume, viewModel.isAtVolumeRoot, viewModel.activeSmartCollection == nil {
                StorageBreakdownView(volume: volume)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            SmartCollectionsSection()

            if viewModel.activeSmartCollection != nil {
                activeCollectionBanner
            }

            listHeader

            Group {
                if viewModel.isShowingGlobalSearch {
                    GlobalSearchResultsView()
                } else {
                    folderList
                }
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            actionBar
        }
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

    private var sidebarHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(L10n.panelBrowser)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    if viewModel.loadedFromCache {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .help(L10n.scanFromCache)
                    }
                }

                HStack(spacing: 3) {
                    if viewModel.isLoading {
                        CompactProgressView(size: 10)
                        Text(viewModel.scanProgress.isEmpty ? L10n.scanLive : viewModel.scanProgress)
                    } else {
                        if let collection = viewModel.activeSmartCollection {
                            Text(collection.title)
                        } else {
                            Text(L10n.itemsCount(viewModel.browserListEntries.count))
                        }
                        Text("·")
                        Text(ByteFormatter.string(from: viewModel.totalSize))
                    }
                }
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 3) {
                Menu {
                    Button(L10n.rebuildSearchIndex) { viewModel.rebuildSearchIndex() }
                    Divider()
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            viewModel.setSortOrder(order)
                        } label: {
                            if viewModel.sortOrder == order {
                                Label(order.title, systemImage: "checkmark")
                            } else {
                                Text(order.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                SidebarIconButton(icon: "arrow.up", isEnabled: viewModel.breadcrumbs.count > 1, help: L10n.goUp) {
                    viewModel.navigateUp()
                }
                SidebarIconButton(icon: "arrow.clockwise", isEnabled: !viewModel.isLoading, help: L10n.refresh) {
                    viewModel.refreshCurrentFolder()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var breadcrumbSection: some View {
        BreadcrumbView(
            breadcrumbs: viewModel.breadcrumbs,
            volumeName: viewModel.selectedVolume?.name ?? L10n.diskLabel
        ) { url in
            viewModel.navigate(to: url)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var listHeader: some View {
        FileListColumnsLayout(
            icon: { Color.clear },
            name: {
                SortColumnButton(title: L10n.columnName, column: .name, alignment: .leading)
            },
            size: {
                SortColumnButton(title: L10n.columnSize, column: .size, alignment: .trailing)
            },
            modified: {
                SortColumnButton(title: L10n.columnModified, column: .date, alignment: .trailing)
            },
            trailing: { Color.clear }
        )
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, FileListColumns.horizontalInset)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.03))
    }

    private var activeCollectionBanner: some View {
        HStack(spacing: 8) {
            if viewModel.isScanningSmartCollection {
                CompactProgressView(size: 12)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.activeSmartCollection?.title ?? L10n.collectionActive)
                    .font(.system(size: 11, weight: .semibold))
                if let progress = viewModel.smartCollectionProgress {
                    Text(progress.status)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if viewModel.isScanningSmartCollection {
                    Text(L10n.collectionScanning)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(L10n.cancel) { viewModel.clearSmartCollection() }
                .buttonStyle(.borderless)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private var folderList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if viewModel.browserListEntries.isEmpty && !viewModel.isLoading && !viewModel.isScanningSmartCollection {
                        emptyFolderState
                    }

                    ForEach(Array(viewModel.browserListEntries.enumerated()), id: \.element.id) { index, item in
                        FolderRowView(
                            item: item,
                            color: DiskColors.color(for: index),
                            totalSize: viewModel.displayTotalSize,
                            isSelected: viewModel.selectedIDs.contains(item.id),
                            isHovered: viewModel.hoveredID == item.id,
                            isKeyboardFocused: viewModel.keyboardFocusedIndex == index,
                            searchQuery: viewModel.debouncedSearchText
                        )
                        .id(item.id)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .draggableItem(item)
                        .onTapGesture(count: 2) {
                            viewModel.handleItemDoubleClick(item)
                        }
                        .onTapGesture {
                            let flags = NSEvent.modifierFlags
                            viewModel.handleItemClick(
                                item, at: index,
                                commandHeld: flags.contains(.command),
                                shiftHeld: flags.contains(.shift)
                            )
                        }
                        .onHover { hovering in
                            if hovering {
                                viewModel.setHoveredID(item.id, keyboardIndex: index)
                            } else {
                                viewModel.setHoveredID(nil)
                            }
                        }
                        .contextMenu { itemContextMenu(item) }
                    }
                }
                .padding(.horizontal, FileListColumns.listPadding)
                .padding(.vertical, 4)
            }
            .onChange(of: viewModel.keyboardFocusedIndex) { index in
                guard index < viewModel.browserListEntries.count else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(viewModel.browserListEntries[index].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func itemContextMenu(_ item: DiskItem) -> some View {
        Button(L10n.detailShowDetails) { viewModel.selectItemForDetail(item) }
        Divider()
        if item.isDirectory && !item.isVirtual { Button(L10n.open) { viewModel.openItem(item) } }
        Button(L10n.addToCollector) { viewModel.addToCollector(item) }
        Button(L10n.revealFinder) { viewModel.revealInFinder(item) }
        Button(L10n.quickLook) { QuickLookService.preview(urls: [item.url]) }
        if !item.isVirtual && CleanupService.canDelete(url: item.url) {
            Divider()
            Button(L10n.moveToTrash, role: .destructive) {
                viewModel.selectedIDs = [item.id]
                viewModel.requestDelete()
            }
        }
    }

    private var emptyFolderState: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.debouncedSearchText.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            Text(viewModel.debouncedSearchText.isEmpty ? L10n.emptyFolder : L10n.noSearchResults)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            VStack(spacing: 6) {
                if !viewModel.selectedIDs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                        Text(L10n.itemsSelected(viewModel.selectedIDs.count))
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.selectedSize.formattedSize)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.addToCollector) {
                            viewModel.selectedItems.forEach { viewModel.addToCollector($0) }
                        }
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.08)))
                }

                Button { viewModel.requestDelete() } label: {
                    Label(L10n.moveToTrash, systemImage: "trash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
                .disabled(viewModel.selectedIDs.isEmpty)

                Text(L10n.hintSidebar(L10n.hintSpace))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        }
    }
}

private struct SidebarIconButton: View {
    let icon: String
    let isEnabled: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEnabled ? .primary : .quaternary)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isEnabled ? 0.06 : 0.03)))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(help)
    }
}

private struct FolderRowView: View {
    let item: DiskItem
    let color: Color
    let totalSize: Int64
    let isSelected: Bool
    let isHovered: Bool
    let isKeyboardFocused: Bool
    var searchQuery: String = ""

    private var fraction: CGFloat {
        guard totalSize > 0 else { return 0 }
        return CGFloat(item.size) / CGFloat(totalSize)
    }

    var body: some View {
        FileListColumnsLayout(
            icon: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(isSelected || isHovered ? 0.22 : 0.12))
                        .frame(width: FileListColumns.iconWidth, height: FileListColumns.iconWidth)
                    if item.isVirtual {
                        Image(systemName: "ellipsis.circle.fill").font(.system(size: 14)).foregroundStyle(.secondary)
                    } else {
                        FileIconView(url: item.url, size: 22)
                    }
                }
            },
            name: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(item.displayName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                        if item.isCloudPlaceholder {
                            Image(systemName: "icloud").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }

                    if item.isScanning {
                        HStack(spacing: 4) {
                            CompactProgressView(size: 10)
                            Text(L10n.scanning).font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    } else {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.06)).frame(height: 3)
                                Capsule().fill(color.opacity(0.75))
                                    .frame(width: max(3, geo.size.width * fraction), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            },
            size: {
                Text(item.isScanning ? "…" : item.formattedSize)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.isScanning ? .secondary : .primary)
            },
            modified: {
                Text(item.isScanning ? "—" : item.formattedModifiedDate)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            },
            trailing: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.quaternary)
                    .opacity(item.isDirectory && !item.isVirtual ? 1 : 0)
            }
        )
        .padding(.horizontal, FileListColumns.rowPadding).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(FileAgeHeatmap.color(for: item.modifiedDate))
                }
                .overlay {
                    if isSelected || isHovered || isKeyboardFocused {
                        RoundedRectangle(cornerRadius: 10).stroke(color.opacity(isSelected ? 0.35 : 0.18), lineWidth: 1)
                    }
                }
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: 3).padding(.vertical, 8)
                        .opacity(isSelected || isHovered ? 1 : 0.5)
                }
        }
    }

    private var rowBackground: Color {
        if isSelected { return color.opacity(0.12) }
        if isKeyboardFocused { return Color.accentColor.opacity(0.06) }
        if isHovered { return Color.primary.opacity(0.04) }
        return Color.primary.opacity(0.02)
    }
}

private extension Int64 {
    var formattedSize: String { ByteFormatter.string(from: self) }
}

private struct FileListColumnsLayout<Icon: View, Name: View, Size: View, Modified: View, Trailing: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let name: () -> Name
    @ViewBuilder let size: () -> Size
    @ViewBuilder let modified: () -> Modified
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: FileListColumns.spacing) {
            icon()
                .frame(width: FileListColumns.iconWidth)
            name()
                .frame(maxWidth: .infinity, alignment: .leading)
            size()
                .frame(width: FileListColumns.sizeWidth, alignment: .trailing)
            modified()
                .frame(width: FileListColumns.modifiedWidth, alignment: .trailing)
            trailing()
                .frame(width: FileListColumns.chevronWidth)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
