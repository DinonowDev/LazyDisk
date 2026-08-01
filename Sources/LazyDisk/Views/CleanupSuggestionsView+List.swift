import SwiftUI

extension CleanupSuggestionsView {
    // MARK: - Breakdown & filters

    var categoryBreakdown: some View {
        let segments = grouped.map { (category: $0.0, size: $0.1.reduce(0) { $0 + $1.size }) }
        let maxSize = max(segments.map(\.size).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.cleanupBreakdown)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .secondaryLabelStyle()

            VStack(spacing: 6) {
                ForEach(segments, id: \.category) { segment in
                    HStack(spacing: 8) {
                        Image(systemName: segment.category.icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(cleanupCategoryColor(segment.category))
                            .frame(width: 14)

                        Text(L10n.goalCategoryTitle(segment.category))
                            .font(.system(size: 10, weight: .medium))
                            .frame(width: 88, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.06))
                                Capsule()
                                    .fill(cleanupCategoryColor(segment.category).opacity(0.75))
                                    .frame(width: max(4, geo.size.width * CGFloat(segment.size) / CGFloat(maxSize)))
                            }
                        }
                        .frame(height: 6)

                        Text(ByteFormatter.string(from: segment.size))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, alignment: .trailing)
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(title: L10n.filterAll, category: nil, isSelected: categoryFilter == nil)
                ForEach(activeCategories, id: \.self) { category in
                    filterChip(
                        title: L10n.goalCategoryTitle(category),
                        category: category,
                        isSelected: categoryFilter == category
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    func filterChip(title: String, category: GoalSuggestionCategory?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { categoryFilter = category }
        } label: {
            HStack(spacing: 4) {
                if let category {
                    Image(systemName: category.icon).font(.system(size: 9))
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

    var controlsRow: some View {
        HStack {
            Menu {
                ForEach(CleanupSortOrder.allCases) { order in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { sortOrder = order }
                    } label: {
                        HStack {
                            Text(order.title)
                            if sortOrder == order { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(sortOrder.title)
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

            Spacer()
        }
    }

    @ViewBuilder
    var listContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(grouped, id: \.0) { category, items in
                categorySection(category: category, items: items)
            }
        }
    }

    func categorySection(category: GoalSuggestionCategory, items: [CleanupSuggestion]) -> some View {
        let total = items.reduce(0) { $0 + $1.size }
        let isExpanded = expandedCategories.contains(category)
        let groupCollected = items.filter { viewModel.isInCollector(url: $0.url) }.count

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expandedCategories.remove(category) }
                    else { expandedCategories.insert(category) }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(cleanupCategoryColor(category).opacity(0.14))
                            .frame(width: 28, height: 28)
                        Image(systemName: category.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(cleanupCategoryColor(category))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.goalCategoryTitle(category))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(L10n.cleanupCategoryCount(items.count))
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
                    ForEach(items) { suggestion in
                        suggestionRow(suggestion, category: category)
                    }
                }
            }
        }
    }

    // MARK: - Footer

    var footerBar: some View {
        HStack(spacing: 12) {
            Button(L10n.cleanupScan) { viewModel.scanCleanupSuggestions() }

            if collectedCount > 0 {
                Text(L10n.devCollectorCount(collectedCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.green.opacity(0.1)))
            }

            Spacer()

            Button(L10n.cleanupAddAll) { viewModel.addAllCleanupSuggestions() }
                .buttonStyle(.borderedProminent)
                .disabled(collectedCount == suggestions.count)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
        .overlay(alignment: .top) { Divider() }
    }
}
