import SwiftUI

enum DiskColors {
    // DaisyDisk-inspired vibrant rainbow palette
    static let daisyDiskPalette: [Color] = [
        Color(red: 0.55, green: 0.25, blue: 0.75), // purple
        Color(red: 0.35, green: 0.30, blue: 0.85), // indigo
        Color(red: 0.20, green: 0.50, blue: 0.90), // blue
        Color(red: 0.15, green: 0.70, blue: 0.85), // cyan
        Color(red: 0.20, green: 0.75, blue: 0.45), // green
        Color(red: 0.55, green: 0.80, blue: 0.25), // lime
        Color(red: 0.90, green: 0.75, blue: 0.20), // yellow
        Color(red: 0.95, green: 0.55, blue: 0.20), // orange
        Color(red: 0.90, green: 0.35, blue: 0.30), // coral
        Color(red: 0.80, green: 0.30, blue: 0.55), // magenta
    ]

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

    static func color(for index: Int, palette: [Color] = palette) -> Color {
        palette[index % palette.count]
    }

    static func gradient(for index: Int, depth: Int = 0, palette: [Color] = palette) -> LinearGradient {
        let base = color(for: index, palette: palette)
        let brighten = 1 + CGFloat(depth) * 0.08
        let top = base.opacity(min(0.98, 0.88 + CGFloat(depth) * 0.04))
        let mid = base.opacity(min(1, 0.95 * brighten))
        let bottom = base.opacity(max(0.65, 0.78 - CGFloat(depth) * 0.06))
        return LinearGradient(
            colors: [top, mid, bottom],
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

    static func spectrumColor(
        hue: CGFloat,
        saturation: CGFloat,
        brightness: CGFloat,
        depth: Int = 0,
        isHovered: Bool = false
    ) -> Color {
        let hoverBoost: CGFloat = isHovered ? 0.08 : 0
        return Color(
            hue: hue,
            saturation: min(1, saturation + hoverBoost),
            brightness: min(1, brightness + hoverBoost)
        )
    }

    static func spectrumColor(forChartIndex index: Int, total: Int, depth: Int = 0) -> Color {
        let hue = CGFloat(index) / CGFloat(max(total, 1))
        return spectrumColor(hue: hue, saturation: 0.78, brightness: 0.58 + CGFloat(depth) * 0.07)
    }
}
