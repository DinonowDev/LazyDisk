import CoreGraphics

enum ChartMetrics {
    /// Matches Rose chart outer ring — keeps all polar charts the same footprint.
    static let maxOuterRadiusRatio: CGFloat = 0.38
    static let hubRadiusRatio: CGFloat = 0.24

    /// Rectangular charts (treemap) may use at most this fraction of their panel.
    static let treemapFillRatio: CGFloat = 0.70
}
