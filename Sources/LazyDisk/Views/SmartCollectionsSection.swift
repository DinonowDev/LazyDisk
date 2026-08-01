import SwiftUI

struct SmartCollectionsSection: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                    Text(L10n.collectionTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if viewModel.isScanningSmartCollection {
                        CompactProgressView(size: 12)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(SmartCollection.allCases) { collection in
                        collectionRow(collection)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 6)
    }

    private func collectionRow(_ collection: SmartCollection) -> some View {
        let isActive = viewModel.activeSmartCollection == collection

        return Button {
            if isActive {
                viewModel.clearSmartCollection()
            } else {
                viewModel.runSmartCollection(collection)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: collection.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(collection.title)
                        .font(.system(size: 11, weight: isActive ? .bold : .medium))
                        .foregroundStyle(isActive ? Color.accentColor : .primary)
                    Text(collection.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isActive, !viewModel.smartCollectionResults.isEmpty {
                    Text("\(viewModel.smartCollectionResults.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
