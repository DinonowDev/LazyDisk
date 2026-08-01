import SwiftUI

struct FreeSpaceGoalView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    private var queuedSuggestions: [GoalSuggestion] {
        viewModel.goalSuggestions.filter { viewModel.isInCollector(url: $0.url) }
    }

    private var groupedSuggestions: [(GoalSuggestionCategory, [GoalSuggestion])] {
        let grouped = Dictionary(grouping: viewModel.goalSuggestions, by: \.category)
        return GoalSuggestionCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader(
                title: L10n.goalTitle,
                subtitle: headerSubtitle
            )

            if let volume = viewModel.selectedVolume {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        statsRow(volume: volume)
                        targetCard(volume: volume)
                        progressCard(volume: volume)

                        if viewModel.goalNeededBytes > 0 {
                            suggestSection
                        } else {
                            goalReachedCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Header

    private var headerSubtitle: String {
        if viewModel.isScanningGoal { return L10n.goalScanning }
        if !viewModel.goalSuggestions.isEmpty {
            return L10n.suggestionsCount(viewModel.goalSuggestions.count)
        }
        return viewModel.selectedVolume.map { "\(L10n.menuBarFree): \($0.formattedAvailable)" } ?? ""
    }

    // MARK: - Stats

    private func statsRow(volume: VolumeInfo) -> some View {
        HStack(spacing: 10) {
            statChip(
                icon: "internaldrive.fill",
                label: L10n.overviewAvailable,
                value: volume.formattedAvailable,
                tint: .green
            )
            statChip(
                icon: "target",
                label: L10n.goalTarget,
                value: ByteFormatter.string(from: viewModel.goalTargetBytes),
                tint: .accentColor
            )
            if viewModel.collectorSize > 0 {
                statChip(
                    icon: "trash.circle.fill",
                    label: L10n.goalWithCollector,
                    value: ByteFormatter.string(from: viewModel.projectedFreeSpace),
                    tint: .orange
                )
            }
            if viewModel.goalNeededBytes > 0 {
                statChip(
                    icon: "exclamationmark.triangle.fill",
                    label: L10n.goalStillNeed,
                    value: ByteFormatter.string(from: viewModel.goalNeededBytes),
                    tint: .orange
                )
            }
        }
    }

    private func statChip(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Target slider

    private func targetCard(volume: VolumeInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.goalTarget)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(ByteFormatter.string(from: viewModel.goalTargetBytes))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }

            Slider(value: $viewModel.freeSpaceGoalGB, in: 1...200, step: 1)
                .onChange(of: viewModel.freeSpaceGoalGB) { _ in
                    viewModel.saveFreeSpaceGoal()
                    viewModel.goalSuggestions = []
                }

            HStack {
                Text(volume.formattedTotal)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("200 GB")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    // MARK: - Progress

    private func progressCard(volume: VolumeInfo) -> some View {
        let target = viewModel.goalTargetBytes
        let current = volume.availableCapacity
        let projected = viewModel.projectedFreeSpace
        let progress = min(1, Double(current) / Double(max(target, 1)))
        let projectedProgress = min(1, Double(projected) / Double(max(target, 1)))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.goalProgress)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(L10n.percentFmt(Int(progress * 100)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: geo.size.width * progress)
                    if projected > current {
                        Capsule()
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: geo.size.width * projectedProgress)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(ByteFormatter.string(from: current)) / \(ByteFormatter.string(from: target))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if projected > current {
                    Text("\(L10n.goalProjectedFree): \(ByteFormatter.string(from: projected))")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    // MARK: - Suggestions

    private var suggestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !queuedSuggestions.isEmpty {
                selectedStrip
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.goalNeedMore(ByteFormatter.string(from: viewModel.goalNeededBytes)))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(L10n.goalScanHint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(L10n.goalSuggest) {
                    viewModel.suggestItemsForGoal()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isScanningGoal)
            }

            if viewModel.isScanningGoal {
                ScanProgressPanelView(
                    title: viewModel.goalScanProgress?.currentTask ?? L10n.goalScanning,
                    subtitle: viewModel.goalScanProgress.map {
                        L10n.progressStepFmt($0.completed + 1, max($0.total, 1))
                    },
                    fraction: viewModel.goalScanProgress?.fraction ?? 0,
                    onCancel: { viewModel.cancelGoalScan() }
                )
                .padding(.horizontal, 0)
            } else if !viewModel.goalSuggestions.isEmpty {
                suggestionsSummary
                suggestionsList
                footerBar
            }
        }
    }

    private var suggestionsSummary: some View {
        HStack(spacing: 12) {
            Label(
                L10n.goalSuggestionsTotal(ByteFormatter.string(from: viewModel.goalSuggestionsTotalSize)),
                systemImage: "sparkles"
            )
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.green)

            if viewModel.goalSuggestionsTotalSize >= viewModel.goalNeededBytes {
                Label(L10n.goalReached, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }

            Spacer()

            if queuedSuggestions.count > 0 {
                Text(L10n.goalCollectorQueued(queuedSuggestions.count))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.06))
        )
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(groupedSuggestions, id: \.0) { category, items in
                VStack(alignment: .leading, spacing: 6) {
                    categoryHeader(category, count: items.count, totalSize: items.reduce(0) { $0 + $1.size })

                    ForEach(items) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            }
        }
    }

    private func categoryHeader(_ category: GoalSuggestionCategory, count: Int, totalSize: Int64) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(categoryColor(category))
            Text(L10n.goalCategoryTitle(category))
                .font(.system(size: 12, weight: .bold))
            Text("· \(count)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(ByteFormatter.string(from: totalSize))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func suggestionRow(_ suggestion: GoalSuggestion) -> some View {
        let isQueued = viewModel.isInCollector(url: suggestion.url)
        let ageTint = FileAgeHeatmap.color(for: suggestion.modifiedDate)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(categoryColor(suggestion.category).opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: suggestion.category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(categoryColor(suggestion.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(suggestion.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    priorityBadge(score: suggestion.score)
                }
                Text(suggestion.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(suggestion.url.deletingLastPathComponent().path)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if let days = suggestion.daysSinceModified {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(L10n.goalDaysUnused(days))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(ByteFormatter.string(from: suggestion.size))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                CollectorToggleButton(url: suggestion.url, size: 20)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isQueued ? Color.red.opacity(0.05) : ageTint.opacity(ageTint == .clear ? 0 : 1))
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isQueued ? Color.red.opacity(0.25) : Color.secondary.opacity(0.1),
                    lineWidth: 1
                )
        )
    }

    private func priorityBadge(score: Int) -> some View {
        let (label, color): (String, Color) = {
            switch score {
            case 75...: return (L10n.goalPriorityHigh, .green)
            case 65..<75: return (L10n.goalPriorityMedium, .orange)
            default: return (L10n.goalPriorityLow, .red.opacity(0.8))
            }
        }()

        return Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Selected strip

    private var selectedStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(L10n.goalSelectedTitle, systemImage: "trash.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.85))
                Spacer()
                Text(ByteFormatter.string(from: queuedSuggestions.reduce(0) { $0 + $1.size }))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(L10n.goalCollectorQueued(queuedSuggestions.count))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(queuedSuggestions) { suggestion in
                        selectedChip(suggestion)
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

    private func selectedChip(_ suggestion: GoalSuggestion) -> some View {
        HStack(spacing: 4) {
            Image(systemName: suggestion.category.icon)
                .font(.system(size: 9))
                .foregroundStyle(categoryColor(suggestion.category))
            Text(suggestion.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text(ByteFormatter.string(from: suggestion.size))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    viewModel.removeFromCollector(url: suggestion.url)
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
        .background(Capsule().fill(Color.red.opacity(0.1)))
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button(L10n.goalSuggest) {
                viewModel.suggestItemsForGoal()
            }
            .disabled(viewModel.isScanningGoal)

            Spacer()

            Button(L10n.goalAddAll) {
                viewModel.addAllGoalSuggestions()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.goalSuggestions.allSatisfy { viewModel.isInCollector(url: $0.url) })
        }
        .padding(.top, 4)
    }

    // MARK: - Goal reached

    private var goalReachedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text(L10n.goalReached)
                .font(.system(size: 16, weight: .bold))
            if viewModel.collectorSize > 0 {
                Text("\(L10n.goalProjectedFree): \(ByteFormatter.string(from: viewModel.projectedFreeSpace))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
            )
    }

    private func categoryColor(_ category: GoalSuggestionCategory) -> Color {
        switch category {
        case .cache: return DiskColors.color(for: 4)
        case .logs: return DiskColors.color(for: 3)
        case .trash: return .red
        case .installers: return DiskColors.color(for: 5)
        case .oldDownloads: return .orange
        case .largeDownloads: return DiskColors.color(for: 0)
        case .oldFiles: return DiskColors.color(for: 7)
        case .devJunk: return DiskColors.color(for: 1)
        case .other: return .secondary
        }
    }
}
