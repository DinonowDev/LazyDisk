import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @Binding var searchScope: SearchScope
    let filterCounts: [ContentFilter: Int]
    @Binding var selectedFilter: ContentFilter
    var isIndexing: Bool
    var indexStatus: String
    var onFilterChange: () -> Void
    var onScopeChange: (SearchScope) -> Void
    @FocusState.Binding var isSearchFocused: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 4) {
            if isExpanded {
                expandedPanel
            } else {
                collapsedBar
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isExpanded)
        .onChange(of: text) { newValue in
            if !newValue.isEmpty { isExpanded = true }
        }
        .onAppear {
            if !text.isEmpty || selectedFilter != .all {
                isExpanded = true
            }
        }
    }

    // MARK: - Collapsed

    private var collapsedBar: some View {
        Button {
            withAnimation { isExpanded = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isSearchFocused = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(L10n.searchFilterScope)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 4)

                if selectedFilter != .all {
                    Text(selectedFilter.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }

                Image(systemName: searchScope.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded

    private var expandedPanel: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                scopeToggle

                HStack(spacing: 6) {
                    Image(systemName: searchScope == .entireVolume ? "sparkle.magnifyingglass" : "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(searchScope == .entireVolume ? Color.accentColor : .secondary)

                    TextField(
                        searchScope == .entireVolume
                            ? L10n.searchPlaceholderVolume
                            : L10n.searchPlaceholder,
                        text: $text
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .focused($isSearchFocused)

                    if isIndexing {
                        CompactProgressView(size: 12)
                            .help(indexStatus)
                    }

                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(searchScope == .entireVolume
                              ? Color.accentColor.opacity(0.08)
                              : Color.primary.opacity(0.05))
                )

                Button {
                    withAnimation { isExpanded = false }
                    isSearchFocused = false
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help(L10n.searchFilterCollapse)
            }

            filterChips
        }
    }

    private var scopeToggle: some View {
        HStack(spacing: 0) {
            ForEach(SearchScope.allCases) { scope in
                Button {
                    searchScope = scope
                    onScopeChange(scope)
                } label: {
                    Image(systemName: scope.icon)
                        .font(.system(size: 9, weight: searchScope == scope ? .bold : .medium))
                        .foregroundStyle(searchScope == scope ? Color.accentColor : .secondary)
                        .frame(width: 26, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(searchScope == scope ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(scope.title)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ContentFilter.allCases) { filter in
                    FilterChip(
                        title: filterTitle(filter),
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        onFilterChange()
                    }
                }
            }
        }
        .frame(height: 22)
    }

    private func filterTitle(_ filter: ContentFilter) -> String {
        let count = filterCounts[filter] ?? 0
        if filter == .all { return "\(filter.title) (\(count))" }
        return count > 0 ? "\(filter.title) (\(count))" : filter.title
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}
