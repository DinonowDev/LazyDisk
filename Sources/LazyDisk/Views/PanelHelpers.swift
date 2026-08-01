import SwiftUI

struct CompactProgressView: View {
    var size: CGFloat = 12

    var body: some View {
        ProgressView()
            .controlSize(.mini)
            .frame(width: size, height: size)
    }
}

@ViewBuilder
func panelHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 20, weight: .bold))
        Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
}

@ViewBuilder
func emptyState(icon: String, text: String, @ViewBuilder actions: () -> some View) -> some View {
    VStack(spacing: 16) {
        Image(systemName: icon)
            .font(.system(size: 40))
            .foregroundStyle(.tertiary)
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        actions()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

struct SmartCollectionLinkBanner: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    let hint: String
    let collections: [SmartCollection]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)

            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .layoutPriority(1)

            ForEach(collections) { collection in
                Button {
                    viewModel.openSmartCollectionInBrowser(collection)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: collection.icon)
                            .font(.system(size: 8, weight: .semibold))
                        Text(collection.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                    .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

// MARK: - Collector toggle

struct CollectorToggleButton: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    let url: URL
    var size: CGFloat = 22

    var body: some View {
        let isAdded = viewModel.isInCollector(url: url)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.toggleCollector(url: url)
            }
        } label: {
            Image(systemName: isAdded ? "minus.circle.fill" : "plus.circle.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isAdded ? Color.red.opacity(0.9) : Color.accentColor)
                .frame(width: size + 4, height: size + 4)
                .scaleEffect(isAdded ? 1.05 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAdded)
        }
        .buttonStyle(.plain)
        .help(isAdded ? L10n.removeFromCollector : L10n.addToCollector)
        .accessibilityLabel(isAdded ? L10n.removeFromCollector : L10n.addToCollector)
    }
}
