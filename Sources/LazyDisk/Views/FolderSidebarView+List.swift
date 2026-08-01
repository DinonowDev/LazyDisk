// FolderSidebarView+List.swift — Scrollable folder list, context menu, and empty state.
import SwiftUI
import AppKit

extension FolderSidebarView {
    var folderList: some View {
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
    func itemContextMenu(_ item: DiskItem) -> some View {
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

    var emptyFolderState: some View {
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

}
