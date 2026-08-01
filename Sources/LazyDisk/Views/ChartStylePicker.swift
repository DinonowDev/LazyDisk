import SwiftUI

struct ChartStylePicker: View {
    @Binding var selection: ChartStyle
    var label: String = L10n.prefChartStyle

    var body: some View {
        Group {
            if L10n.isRTL {
                Picker(label, selection: $selection) {
                    ForEach(ChartStyle.allCases) { style in
                        Label(style.title, systemImage: style.icon).tag(style)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Picker(label, selection: $selection) {
                    ForEach(ChartStyle.allCases) { style in
                        Label(style.title, systemImage: style.icon).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
            }
        }
    }
}
