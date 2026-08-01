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
        VStack(alignment: .leading, spacing: 8) {
            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(collections) { collection in
                    Button {
                        viewModel.openSmartCollectionInBrowser(collection)
                    } label: {
                        Label(collection.title, systemImage: collection.icon)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.06)))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
