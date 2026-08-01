import SwiftUI

extension CleanupSuggestionsView {
    // MARK: - Selected strip

    var selectedStrip: some View {
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

    func selectedChip(_ item: CleanupSuggestion) -> some View {
        HStack(spacing: 4) {
            Image(systemName: item.displayCategory.icon)
                .font(.system(size: 9))
                .foregroundStyle(cleanupCategoryColor(item.displayCategory))
            Text(item.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            Text(ByteFormatter.string(from: item.size))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
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
        .background(Capsule().fill(Color.red.opacity(0.1)))
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Row

    func suggestionRow(_ suggestion: CleanupSuggestion, category: GoalSuggestionCategory) -> some View {
        let isAdded = viewModel.isInCollector(url: suggestion.url)
        let tint = cleanupCategoryColor(category)

        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint)
                .frame(width: 4)
                .padding(.vertical, 2)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(suggestion.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    priorityBadge(score: suggestion.score)
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

                Text(suggestion.reason)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(suggestion.url.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                Text(ByteFormatter.string(from: suggestion.size))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isAdded ? .green : .primary)

                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([suggestion.url])
                    } label: {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.revealFinder)

                    CollectorToggleButton(url: suggestion.url, size: 18)
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
    }

    func priorityBadge(score: Int) -> some View {
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

    func miniStat(value: String, label: String, icon: String, tint: Color = .secondary) -> some View {
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

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
