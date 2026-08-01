import SwiftUI
import LazyDiskCore

enum DevJunkGroupMode: String, CaseIterable {
    case project
    case type
}

struct DevModeView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State private var groupMode: DevJunkGroupMode = .project
    @State private var ecosystemFilter: DevJunkEcosystem?
    @State private var sortOrder: DevJunkSortOrder = .sizeDescending
    @State private var expandedGroups: Set<String> = []

    private var items: [DevJunkItem] { viewModel.devJunkItems }
    private var filtered: [DevJunkItem] {
        guard let eco = ecosystemFilter else { return items }
        return items.filter { $0.ecosystem == eco }
    }
    private var summary: DevJunkSummary { DevJunkMetadata.summarize(filtered) }

    private var collectedCount: Int {
        items.filter { viewModel.isInCollector(url: $0.url) }.count
    }

    private var queuedItems: [DevJunkItem] {
        items.filter { viewModel.isInCollector(url: $0.url) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.devTitle,
                subtitle: headerSubtitle
            )

            SmartCollectionLinkBanner(
                hint: L10n.devCollectionsHint,
                collections: JunkPathCatalog.collections(for: .dev)
            )

            if viewModel.isScanningDev {
                ScanProgressPanelView.centered(
                    title: L10n.devScan,
                    subtitle: viewModel.devProgress.map { L10n.scanProgressFmt($0.found, max($0.scannedDirs, 1)) },
                    fraction: viewModel.devProgress?.fraction ?? 0,
                    detail: viewModel.devProgress?.currentPath,
                    onCancel: { viewModel.cancelDevScan() }
                )
            } else if items.isEmpty {
                emptyState(icon: "chevron.left.forwardslash.chevron.right", text: L10n.devEmpty) {
                    VStack(spacing: 8) {
                        Text(L10n.devEmptyDesc)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                        Button(L10n.devScan) { viewModel.scanDevJunk() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryCard
                        if !queuedItems.isEmpty {
                            selectedStrip
                        }
                        filterBar
                        controlsRow
                        listContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                footerBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .onChange(of: items.count) { _ in
            expandedGroups = Set(groupedByProject.keys)
        }
        .onAppear {
            viewModel.syncDevJunkDisplay()
            if expandedGroups.isEmpty {
                expandedGroups = Set(groupedByProject.keys)
            }
        }
    }

    // MARK: - Selected strip

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.devSelectedTitle, systemImage: "trash.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
                Spacer()
                Text(ByteFormatter.string(from: queuedItems.reduce(0) { $0 + $1.size }))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(L10n.devCollectorCount(queuedItems.count))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(queuedItems) { item in
                        selectedChip(item)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.red.opacity(0.18), lineWidth: 1)
        )
    }

    private func selectedChip(_ item: DevJunkItem) -> some View {
        HStack(spacing: 4) {
            Text(item.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            if let project = item.projectName {
                Text("· \(project)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    viewModel.removeFromCollector(url: item.url)
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help(L10n.removeFromCollector)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Color.red.opacity(0.1))
        )
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
    }

    @ViewBuilder
    private var listContent: some View {
        if groupMode == .project {
            projectGroupedList
        } else {
            typeGroupedList
        }
    }

    private var headerSubtitle: String {
        if items.isEmpty { return L10n.devEmpty }
        let s = DevJunkMetadata.summarize(items)
        return L10n.devSummarySubtitle(
            items: s.itemCount,
            projects: s.projectCount,
            size: ByteFormatter.string(from: s.totalSize)
        )
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 16) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.devReclaimable)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .secondaryLabelStyle()
                Text(ByteFormatter.string(from: summary.totalSize))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                miniStat(value: "\(summary.itemCount)", label: L10n.devItemsLabel, icon: "folder.fill")
                if summary.projectCount > 0 {
                    miniStat(value: "\(summary.projectCount)", label: L10n.devProjectsLabel, icon: "chevron.left.forwardslash.chevron.right")
                }
                if collectedCount > 0 {
                    miniStat(value: "\(collectedCount)", label: L10n.devInCollector, icon: "checkmark.circle.fill", tint: .green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func miniStat(value: String, label: String, icon: String, tint: Color = .secondary) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(title: L10n.devFilterAll, eco: nil, isSelected: ecosystemFilter == nil)
                ForEach(activeEcosystems, id: \.self) { eco in
                    filterChip(title: L10n.devEcoName(eco), eco: eco, isSelected: ecosystemFilter == eco)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var activeEcosystems: [DevJunkEcosystem] {
        let set = Set(items.map(\.ecosystem))
        return DevJunkEcosystem.allCases.filter { set.contains($0) }
    }

    private func filterChip(title: String, eco: DevJunkEcosystem?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { ecosystemFilter = eco }
        } label: {
            HStack(spacing: 4) {
                if let eco {
                    Image(systemName: eco.icon).font(.system(size: 9))
                }
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(Capsule().strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var groupModePicker: some View {
        Picker("", selection: $groupMode) {
            Text(L10n.devGroupByProject).tag(DevJunkGroupMode.project)
            Text(L10n.devGroupByType).tag(DevJunkGroupMode.type)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            groupModePicker

            Menu {
                ForEach(DevJunkSortOrder.allCases) { order in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { sortOrder = order }
                    } label: {
                        HStack {
                            Text(L10n.devSortTitle(order))
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L10n.devSortTitle(sortOrder))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Grouped lists

    private var groupedByProject: [String: [DevJunkItem]] {
        Dictionary(grouping: filtered) { $0.groupKey }
    }

    private var groupedByPurpose: [DevJunkPurpose: [DevJunkItem]] {
        Dictionary(grouping: filtered) { $0.purpose }
    }

    private var projectGroupedList: some View {
        let groups = sortOrder.sortProjectGroups(
            groupedByProject.map { (key: $0.key, items: $0.value) }
        )

        return LazyVStack(spacing: 8) {
            ForEach(groups, id: \.key) { group in
                groupSection(
                    key: group.key,
                    title: groupTitle(for: group.key, items: group.items),
                    subtitle: groupSubtitle(items: group.items),
                    icon: groupIcon(for: group.key, items: group.items),
                    items: group.items
                )
            }
        }
    }

    private var typeGroupedList: some View {
        let purposeOrder: [DevJunkPurpose] = [
            .dependencies, .buildOutput, .buildCache, .devServerCache,
            .testCache, .languageCache, .packageManager, .runtimeData, .tooling
        ]
        let baseGroups = purposeOrder.compactMap { purpose -> (DevJunkPurpose, [DevJunkItem])? in
            guard let items = groupedByPurpose[purpose], !items.isEmpty else { return nil }
            return (purpose, items)
        }
        let groups = sortOrder.sortPurposeGroups(
            baseGroups.map { (purpose: $0.0, items: $0.1) }
        )

        return LazyVStack(spacing: 8) {
            ForEach(groups, id: \.purpose) { group in
                groupSection(
                    key: group.purpose.rawValue,
                    title: L10n.devPurposeName(group.purpose),
                    subtitle: L10n.devPurposeDesc(group.purpose),
                    icon: group.purpose.icon,
                    items: group.items
                )
            }
        }
    }

    private func groupSection(key: String, title: String, subtitle: String, icon: String, items: [DevJunkItem]) -> some View {
        let total = items.reduce(0) { $0 + $1.size }
        let isExpanded = expandedGroups.contains(key)
        let groupCollected = items.filter { viewModel.isInCollector(url: $0.url) }.count

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedGroups.remove(key) }
                    else { expandedGroups.insert(key) }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(ecosystemColor(items.first?.ecosystem ?? .general).opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ecosystemColor(items.first?.ecosystem ?? .general))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if groupCollected > 0 {
                        Text("\(groupCollected)/\(items.count)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                    }

                    Text(ByteFormatter.string(from: total))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.quaternary)
                        .frame(width: 12)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(items) { item in
                        junkRow(item)
                    }
                }
            }
        }
    }

    // MARK: - Row

    private func junkRow(_ item: DevJunkItem) -> some View {
        let isAdded = viewModel.isInCollector(url: item.url)

        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(ecosystemColor(item.ecosystem))
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if let project = item.projectName {
                        Text(project)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if isAdded {
                        Label(L10n.devInCollector, systemImage: "checkmark")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                    }
                }

                HStack(spacing: 4) {
                    badge(text: L10n.devEcoName(item.ecosystem), color: ecosystemColor(item.ecosystem))
                    badge(text: L10n.devPurposeName(item.purpose), color: .orange)
                    safetyBadge(item.safety)
                }

                Text(L10n.devFolderDesc(item.folderKind))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.url.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(ByteFormatter.string(from: item.size))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isAdded ? .green : .primary)

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([item.url])
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.revealFinder)

                    CollectorToggleButton(url: item.url, size: 18)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAdded
                    ? Color.green.opacity(0.07)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isAdded ? Color.green.opacity(0.35) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isAdded)
        .animation(.easeInOut(duration: 0.2), value: viewModel.collectorItems.count)
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .foregroundStyle(color)
    }

    private func safetyBadge(_ safety: DevJunkSafety) -> some View {
        HStack(spacing: 2) {
            Image(systemName: safety.icon).font(.system(size: 7))
            Text(L10n.devSafetyName(safety))
                .font(.system(size: 8, weight: .semibold))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Capsule().fill(safetyColor(safety).opacity(0.12)))
        .foregroundStyle(safetyColor(safety))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 12) {
            Button(L10n.devScan) { viewModel.scanDevJunk() }

            if collectedCount > 0 {
                Text(L10n.devCollectorCount(collectedCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.1)))
            }

            Spacer()

            Button(L10n.cleanupAddAll) { viewModel.addAllDevJunk() }
                .buttonStyle(.borderedProminent)
                .disabled(collectedCount == items.count)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Helpers

    private func groupTitle(for key: String, items: [DevJunkItem]) -> String {
        if key == "__global__" { return L10n.devGlobalCaches }
        return items.first?.projectName ?? key.components(separatedBy: "/").last ?? key
    }

    private func groupSubtitle(items: [DevJunkItem]) -> String {
        if items.first?.isGlobal == true { return L10n.devGlobalCachesDesc }
        let ecosystems = Set(items.map(\.ecosystem))
        let names = ecosystems.map { L10n.devEcoName($0) }.sorted().joined(separator: " · ")
        if let path = items.first?.projectPath?.path {
            return "\(names) — \(path)"
        }
        return names
    }

    private func groupIcon(for key: String, items: [DevJunkItem]) -> String {
        if key == "__global__" { return "globe" }
        return items.first?.ecosystem.icon ?? "folder.fill"
    }

    private func ecosystemColor(_ eco: DevJunkEcosystem) -> Color {
        switch eco {
        case .javascript: return Color(red: 0.97, green: 0.87, blue: 0.12)
        case .typescript: return Color(red: 0.20, green: 0.47, blue: 0.78)
        case .python: return Color(red: 0.22, green: 0.46, blue: 0.67)
        case .rust: return Color(red: 0.87, green: 0.65, blue: 0.52)
        case .go: return Color(red: 0.0, green: 0.68, blue: 0.85)
        case .swift: return Color(red: 0.94, green: 0.32, blue: 0.22)
        case .java: return Color(red: 0.93, green: 0.55, blue: 0.0)
        case .kotlin: return Color(red: 0.45, green: 0.31, blue: 0.82)
        case .ruby: return Color(red: 0.84, green: 0.0, blue: 0.0)
        case .php: return Color(red: 0.47, green: 0.52, blue: 0.72)
        case .dart: return Color(red: 0.0, green: 0.59, blue: 0.82)
        case .docker: return Color(red: 0.14, green: 0.59, blue: 0.93)
        case .homebrew: return Color(red: 0.98, green: 0.60, blue: 0.15)
        case .ios: return Color(red: 0.0, green: 0.48, blue: 0.98)
        case .android: return Color(red: 0.26, green: 0.76, blue: 0.44)
        case .web: return Color(red: 0.0, green: 0.74, blue: 0.65)
        case .csharp: return Color(red: 0.40, green: 0.20, blue: 0.72)
        case .general: return .secondary
        }
    }

    private func safetyColor(_ safety: DevJunkSafety) -> Color {
        switch safety {
        case .safe: return .green
        case .rebuild: return .orange
        case .caution: return .red
        }
    }
}
