import SwiftUI

struct CleanupSuggestionsView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State var categoryFilter: GoalSuggestionCategory?
    @State var sortOrder: CleanupSortOrder = .scoreDescending
    @State var expandedCategories: Set<GoalSuggestionCategory> = []

    var suggestions: [CleanupSuggestion] { viewModel.cleanupSuggestions }

    private var filtered: [CleanupSuggestion] {
        guard let categoryFilter else { return suggestions }
        return suggestions.filter { $0.displayCategory == categoryFilter }
    }

    var grouped: [(GoalSuggestionCategory, [CleanupSuggestion])] {
        let grouped = Dictionary(grouping: filtered, by: \.displayCategory)
        return GoalSuggestionCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, sortOrder.sort(items))
        }
        .sorted { $0.0.sortOrder < $1.0.sortOrder }
    }

    var totalSize: Int64 { filtered.reduce(0) { $0 + $1.size } }

    var collectedCount: Int {
        suggestions.filter { viewModel.isInCollector(url: $0.url) }.count
    }

    var queuedItems: [CleanupSuggestion] {
        suggestions.filter { viewModel.isInCollector(url: $0.url) }
    }

    var activeCategories: [GoalSuggestionCategory] {
        let set = Set(suggestions.map(\.displayCategory))
        return GoalSuggestionCategory.allCases.filter { set.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(title: L10n.cleanupTitle, subtitle: headerSubtitle)

            SmartCollectionLinkBanner(
                hint: L10n.cleanupCollectionsHint,
                collections: JunkPathCatalog.collections(for: .cleanup)
            )

            if viewModel.isScanningCleanup {
                ScanProgressPanelView.centered(
                    title: viewModel.cleanupProgress?.currentTask ?? L10n.cleanupScan,
                    subtitle: cleanupSubtitle,
                    fraction: viewModel.cleanupProgress?.fraction ?? 0,
                    detail: cleanupDetail,
                    onCancel: { viewModel.cancelCleanupScan() }
                )
            } else if suggestions.isEmpty {
                emptyState(icon: "sparkles", text: L10n.cleanupEmpty) {
                    VStack(spacing: 8) {
                        Text(L10n.cleanupEmptyDesc)
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                        Button(L10n.cleanupScan) { viewModel.scanCleanupSuggestions() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        summaryCard
                        categoryBreakdown
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
        .onChange(of: suggestions.count) { _ in
            expandedCategories = Set(activeCategories)
        }
        .onAppear {
            if expandedCategories.isEmpty {
                expandedCategories = Set(activeCategories)
            }
        }
    }

    // MARK: - Header

    private var headerSubtitle: String {
        if viewModel.isScanningCleanup { return L10n.cleanupScan }
        if suggestions.isEmpty { return L10n.cleanupEmpty }
        return L10n.cleanupSummarySubtitle(
            items: suggestions.count,
            size: ByteFormatter.string(from: suggestions.reduce(0) { $0 + $1.size })
        )
    }

    private var cleanupSubtitle: String? {
        guard let p = viewModel.cleanupProgress else { return nil }
        return L10n.progressStepFmt(p.completed + 1, max(p.total, 1))
    }

    private var cleanupDetail: String? {
        guard let p = viewModel.cleanupProgress, !p.currentTask.isEmpty else { return nil }
        return p.currentTask
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(alignment: .center, spacing: 16) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange, Color.orange.opacity(0.5)],
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
                Text(ByteFormatter.string(from: totalSize))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                miniStat(value: "\(filtered.count)", label: L10n.devItemsLabel, icon: "sparkles")
                if collectedCount > 0 {
                    miniStat(
                        value: "\(collectedCount)",
                        label: L10n.devInCollector,
                        icon: "checkmark.circle.fill",
                        tint: .green
                    )
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }
}
