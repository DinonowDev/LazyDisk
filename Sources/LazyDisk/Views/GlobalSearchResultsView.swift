import SwiftUI

struct GlobalSearchResultsView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(spacing: 0) {
            resultsHeader
            Divider().opacity(0.4)

            if viewModel.isGlobalSearching {
                searchingState
            } else if viewModel.globalSearchResults.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
    }

    private var resultsHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.searchResults)
                    .font(.system(size: 12, weight: .bold))

                HStack(spacing: 6) {
                    Text("\"\(viewModel.debouncedSearchText)\"")
                        .lineLimit(1)
                    if !viewModel.isGlobalSearching {
                        Text("·")
                        Text(L10n.searchResultCount(viewModel.globalSearchResults.count))
                    }
                    if let engine = viewModel.globalSearchEngine {
                        engineBadge(engine)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.isBuildingSearchIndex {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                    Text(viewModel.searchIndexStatus)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            } else if viewModel.searchIndexEntryCount > 0 {
                Text(L10n.searchIndexCount(viewModel.searchIndexEntryCount))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.05))
    }

    private func engineBadge(_ engine: SearchEngine) -> some View {
        let label: String
        let icon: String
        switch engine {
        case .spotlight: label = L10n.searchEngineSpotlight; icon = "sparkle.magnifyingglass"
        case .index: label = L10n.searchEngineIndex; icon = "cylinder.split.1x2"
        case .filesystem: label = L10n.searchEngineLive; icon = "waveform"
        }

        return HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8))
            Text(label)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }

    private var searchingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(L10n.searchSearching)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(L10n.searchNoResults)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 48)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.globalSearchResults) { result in
                    GlobalSearchRow(result: result)
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture(count: 2) {
                            viewModel.openSearchResult(result)
                        }
                        .onTapGesture {
                            viewModel.navigateToSearchResult(result)
                        }
                        .contextMenu { resultContextMenu(result) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func resultContextMenu(_ result: GlobalSearchResult) -> some View {
        Button(L10n.searchGoToFolder) { viewModel.navigateToSearchResult(result) }
        if result.isDirectory {
            Button(L10n.open) { viewModel.openSearchResult(result) }
        }
        Button(L10n.addToCollector) { viewModel.addToCollector(result.diskItem) }
        Button(L10n.revealFinder) { viewModel.revealInFinder(result.diskItem) }
        Button(L10n.quickLook) { QuickLookService.preview(urls: [result.url]) }
    }
}

private struct GlobalSearchRow: View {
    let result: GlobalSearchResult

    var body: some View {
        HStack(spacing: 10) {
            FileIconView(url: result.url, size: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(result.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    if result.isHidden {
                        Text(L10n.hiddenLabel)
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.07)))
                    }
                }

                Text(result.formattedPath)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                if result.size > 0 {
                    Text(ByteFormatter.string(from: result.size))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                Text(result.fileKind.title)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .draggableItem(result.diskItem)
    }
}
