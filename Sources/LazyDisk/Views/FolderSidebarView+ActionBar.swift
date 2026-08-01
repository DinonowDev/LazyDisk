// FolderSidebarView+ActionBar.swift — Selection summary and trash action bar.
import SwiftUI
import AppKit

extension FolderSidebarView {
    var actionBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            VStack(spacing: 6) {
                if !viewModel.selectedIDs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                        Text(L10n.itemsSelected(viewModel.selectedIDs.count))
                            .font(.system(size: 11, weight: .semibold))
                        Text(viewModel.selectedSize.formattedSize)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.addToCollector) {
                            viewModel.selectedItems.forEach { viewModel.addToCollector($0) }
                        }
                        .controlSize(.mini)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.08)))
                }

                Button { viewModel.requestDelete() } label: {
                    Label(L10n.moveToTrash, systemImage: "trash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
                .disabled(viewModel.selectedIDs.isEmpty)

                Text(L10n.hintSidebar(L10n.hintSpace))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        }
    }

}
