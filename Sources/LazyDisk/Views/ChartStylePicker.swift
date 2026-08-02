import SwiftUI

struct ChartStylePicker: View {
    @Binding var selection: ChartStyle
    var styles: [ChartStyle] = ChartStyle.selectableCases

    var body: some View {
        HStack(spacing: 2) {
            ForEach(styles) { style in
                Button {
                    selection = style
                } label: {
                    Image(systemName: style.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 28)
                        .foregroundStyle(selection == style ? Color.accentColor : Color.secondary)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == style
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.primary.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .help(style.title)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
