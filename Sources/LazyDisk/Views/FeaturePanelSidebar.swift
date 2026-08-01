import SwiftUI

struct FeaturePanelSidebar: View {
    @Binding var selectedPanel: AppPanel

    var body: some View {
        VStack(spacing: 4) {
            ForEach(AppPanel.allCases) { panel in
                Button {
                    selectedPanel = panel
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(panel.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: 56, height: 52)
                    .foregroundStyle(selectedPanel == panel ? Color.accentColor : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedPanel == panel ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(panel.title)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 68)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}
