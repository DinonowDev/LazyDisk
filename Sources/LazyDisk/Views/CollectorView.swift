import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CollectorView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isCollectorMinimized {
                minimizedBar
            } else {
                Divider().opacity(0.5)
                collapsedBar
                if viewModel.isCollectorExpanded {
                    expandedContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: viewModel.isCollectorExpanded)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: viewModel.isCollectorMinimized)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.collectorItems.count)
    }

    // MARK: - Minimized bar

    private var minimizedBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewModel.collectorItems.isEmpty ? Color.secondary : Color.red)

            Text(L10n.collectorTitle)
                .font(.system(size: 11, weight: .semibold))

            if !viewModel.collectorItems.isEmpty {
                Text("\(viewModel.collectorItems.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.red))

                Text(ByteFormatter.string(from: viewModel.collectorSize))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 4)

            Button {
                withAnimation { viewModel.isCollectorMinimized = false }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(L10n.collectorRestore)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(collectorBackground)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    // MARK: - Collapsed bar (always visible)

    private var collapsedBar: some View {
        HStack(spacing: 14) {
            collectorIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(L10n.collectorTitle)
                        .font(.system(size: 13, weight: .bold))

                    if !viewModel.collectorItems.isEmpty {
                        Text("\(viewModel.collectorItems.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }

                if viewModel.collectorItems.isEmpty {
                    Text(L10n.collectorEmpty)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    HStack(spacing: 6) {
                        Text(L10n.collectorFree)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(ByteFormatter.string(from: viewModel.collectorSize))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.green)

                        if viewModel.collectorFreePercent > 0.1 {
                            Text(String(format: "(%.1f%% \(L10n.collectorPercent))", viewModel.collectorFreePercent))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            if !viewModel.collectorItems.isEmpty {
                freeSpaceRing
            }

            collectorActions
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(collectorBackground)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.selectedVolume != nil, !viewModel.collectorItems.isEmpty {
                HStack {
                    Text(L10n.collectorAfterDelete)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(ByteFormatter.string(from: viewModel.projectedFreeSpace))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 18)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.collectorItems) { item in
                        CollectorChip(item: item) {
                            viewModel.removeFromCollector(item)
                        }
                        .onTapGesture(count: 2) {
                            viewModel.revealInFinder(item)
                        }
                        .contextMenu {
                            Button(L10n.revealFinder) { viewModel.revealInFinder(item) }
                            Button(L10n.quickLook) { QuickLookService.preview(urls: [item.url]) }
                            Divider()
                            Button(L10n.removeFromCollector) { viewModel.removeFromCollector(item) }
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(maxHeight: 42)
        }
        .padding(.bottom, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Components

    private var collectorIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(viewModel.collectorItems.isEmpty ? 0.12 : 0.24),
                            Color.orange.opacity(viewModel.collectorItems.isEmpty ? 0.08 : 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .scaleEffect(isTargeted ? 1.08 : 1)
                .animation(.spring(response: 0.3), value: isTargeted)

            Image(systemName: isTargeted ? "trash.circle" : "trash.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(viewModel.collectorItems.isEmpty ? Color.secondary : Color.red)
        }
    }

    private var freeSpaceRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: min(CGFloat(viewModel.collectorFreePercent) / 100, 1))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))

            Text(String(format: "%.0f%%", viewModel.collectorFreePercent))
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var collectorActions: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation { viewModel.isCollectorMinimized = true }
            } label: {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help(L10n.collectorMinimize)

            Button {
                withAnimation { viewModel.isCollectorExpanded.toggle() }
            } label: {
                Image(systemName: viewModel.isCollectorExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help(viewModel.isCollectorExpanded ? L10n.collectorCollapse : L10n.collectorExpand)
            .disabled(viewModel.collectorItems.isEmpty)

            Button(L10n.collectorClear) { viewModel.clearCollector() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.collectorItems.isEmpty)

            Button { viewModel.requestCollectorDelete() } label: {
                Label(L10n.collectorDelete, systemImage: "trash.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
            .disabled(viewModel.collectorItems.isEmpty)
        }
    }

    private var collectorBackground: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor).opacity(0.9)
            if isTargeted {
                Color.red.opacity(0.07)
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(Color.red.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let nsurl = item as? NSURL {
                        url = nsurl as URL
                    }
                    guard let url else { return }
                    Task { @MainActor in
                        viewModel.addToCollector(url: url)
                        viewModel.isCollectorMinimized = false
                        if !viewModel.isCollectorExpanded {
                            viewModel.isCollectorExpanded = true
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
}

private struct CollectorChip: View {
    let item: DiskItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            FileIconView(url: item.url, size: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: 110, alignment: .leading)
                Text(item.formattedSize)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        )
    }
}

struct ItemDragModifier: ViewModifier {
    let item: DiskItem
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.onDrag {
                let provider = NSItemProvider(object: item.url as NSURL)
                provider.suggestedName = item.displayName
                return provider
            }
        } else {
            content
        }
    }
}

extension View {
    func draggableItem(_ item: DiskItem, enabled: Bool = true) -> some View {
        modifier(ItemDragModifier(item: item, enabled: enabled && !item.isVirtual))
    }
}
