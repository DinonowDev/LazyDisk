import SwiftUI

enum DiskColors {
    // ECharts-inspired palette
    static let palette: [Color] = [
        Color(red: 0.329, green: 0.439, blue: 0.776), // #5470C6
        Color(red: 0.569, green: 0.800, blue: 0.459), // #91CC75
        Color(red: 0.314, green: 0.325, blue: 0.447), // #505372
        Color(red: 0.933, green: 0.400, blue: 0.400), // #EE6666
        Color(red: 0.451, green: 0.753, blue: 0.871), // #73C0DE
        Color(red: 0.980, green: 0.784, blue: 0.345), // #FAC858
        Color(red: 0.933, green: 0.478, blue: 0.620), // #EE7A9E
        Color(red: 0.604, green: 0.376, blue: 0.706), // #9A60B4
        Color(red: 0.259, green: 0.647, blue: 0.580), // teal
        Color(red: 0.847, green: 0.451, blue: 0.451), // coral
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func gradient(for index: Int) -> LinearGradient {
        let base = color(for: index)
        return LinearGradient(
            colors: [
                base.opacity(0.92),
                base,
                base.opacity(0.78)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func radialGradient(for index: Int) -> RadialGradient {
        let base = color(for: index)
        return RadialGradient(
            colors: [base.opacity(0.95), base.opacity(0.72)],
            center: .center,
            startRadius: 0,
            endRadius: 120
        )
    }
}
