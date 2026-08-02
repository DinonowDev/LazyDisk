// FolderSidebarRow.swift — file list row layout, columns, and icon button.
import SwiftUI
import AppKit

enum FileListColumns {
    static let listPadding: CGFloat = 10
    static let rowPadding: CGFloat = 10
    static var horizontalInset: CGFloat { listPadding + rowPadding }

    struct Tier: Sendable {
        let spacing: CGFloat
        let iconWidth: CGFloat
        let sizeWidth: CGFloat
        let showChevron: Bool

        static let standard = Tier(spacing: 10, iconWidth: 32, sizeWidth: 72, showChevron: true)
        static let compact = Tier(spacing: 8, iconWidth: 28, sizeWidth: 56, showChevron: false)
        static let minimal = Tier(spacing: 6, iconWidth: 24, sizeWidth: 48, showChevron: false)

        static let all: [Tier] = [.standard, .compact, .minimal]
    }
}

struct SidebarIconButton: View {
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

struct FolderRowView: View {
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
                            .truncationMode(.tail)
                        if item.isCloudPlaceholder {
                            Image(systemName: "icloud").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }

                    if item.isScanning {
                        HStack(spacing: 4) {
                            CompactProgressView(size: 10)
                            Text(L10n.scanning).font(.system(size: 9)).foregroundStyle(.secondary)
                                .lineLimit(1)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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

extension Int64 {
    var formattedSize: String { ByteFormatter.string(from: self) }
}

struct FileListColumnsLayout<Icon: View, Name: View, Size: View, Trailing: View>: View {
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let name: () -> Name
    @ViewBuilder let size: () -> Size
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(FileListColumns.Tier.all.enumerated()), id: \.offset) { _, tier in
                row(for: tier)
            }
        }
    }

    @ViewBuilder
    private func row(for tier: FileListColumns.Tier) -> some View {
        HStack(spacing: tier.spacing) {
            icon()
                .frame(width: tier.iconWidth, height: tier.iconWidth)

            name()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            size()
                .frame(width: tier.sizeWidth, alignment: .trailing)
                .layoutPriority(1)

            if tier.showChevron {
                trailing()
                    .frame(width: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
