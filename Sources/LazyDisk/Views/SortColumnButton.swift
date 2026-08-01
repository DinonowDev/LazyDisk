import SwiftUI

struct SortColumnButton: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    let title: String
    let column: SortColumn
    var alignment: Alignment = .leading

    var body: some View {
        Button {
            viewModel.toggleSort(for: column)
        } label: {
            HStack(spacing: 3) {
                Text(title)
                if viewModel.sortOrder.isActive(for: column) {
                    Image(systemName: viewModel.sortOrder.isAscending(for: column) ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
