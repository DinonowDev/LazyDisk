import SwiftUI

private struct PanelWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func trackPanelWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: PanelWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .onPreferenceChange(PanelWidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            onChange(width)
        }
    }
}
