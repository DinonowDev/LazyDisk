// FolderSidebarView+Header.swift — Header, breadcrumbs, list columns, and collection banner.
import SwiftUI
import AppKit

extension FolderSidebarView {
    var sidebarBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [Color.primary.opacity(0.02), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    var sidebarHeader: some View {
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
                    Text(viewModel.isDetailPanelVisible ? L10n.detailTitle : L10n.panelBrowser)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                    if viewModel.loadedFromCache && !viewModel.isDetailPanelVisible {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                            .help(L10n.scanFromCache)
                    }
                }

                HStack(spacing: 3) {
                    if viewModel.isDetailPanelVisible, let item = viewModel.detailItem {
                        Text(item.displayName)
                            .lineLimit(1)
                    } else if viewModel.isLoading {
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

                SidebarIconButton(
                    icon: viewModel.isDetailPanelVisible ? "chevron.left" : "arrow.up",
                    isEnabled: viewModel.isDetailPanelVisible || viewModel.breadcrumbs.count > 1,
                    help: viewModel.isDetailPanelVisible ? L10n.back : L10n.goUp
                ) {
                    if viewModel.isDetailPanelVisible {
                        viewModel.closeDetailPanel()
                    } else {
                        viewModel.navigateUp()
                    }
                }
                SidebarIconButton(icon: "arrow.clockwise", isEnabled: !viewModel.isLoading, help: L10n.refresh) {
                    viewModel.refreshCurrentFolder()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    var breadcrumbSection: some View {
        BreadcrumbView(
            breadcrumbs: viewModel.navigationBreadcrumbs,
            volumeName: viewModel.selectedVolume?.name ?? L10n.diskLabel
        ) { url in
            if viewModel.isDetailPanelVisible,
               let item = viewModel.detailItem,
               PathUtils.resolved(url).path == PathUtils.resolved(item.url).path {
                return
            }
            viewModel.navigate(to: url)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    var listHeader: some View {
        FileListColumnsLayout(
            icon: { Color.clear },
            name: {
                SortColumnButton(title: L10n.columnName, column: .name, alignment: .leading)
            },
            size: {
                SortColumnButton(title: L10n.columnSize, column: .size, alignment: .trailing)
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

    var activeCollectionBanner: some View {
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

}
