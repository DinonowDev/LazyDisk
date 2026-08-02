import Foundation

/// Thresholds for lazy sunburst/treemap subtree scans — skip deep walks for small branches.
public enum ChartLazyScanPolicy {
  public static let minimumThresholdBytes: Int64 = 100 * 1024 * 1024
  public static let maximumThresholdBytes: Int64 = 3 * 1024 * 1024 * 1024
  public static let relativeFraction = 0.005

  public static func deepScanThreshold(parentTotalSize: Int64) -> Int64 {
    guard parentTotalSize > 0 else { return minimumThresholdBytes }
    let relative = Int64(Double(parentTotalSize) * relativeFraction)
    return min(max(minimumThresholdBytes, relative), maximumThresholdBytes)
  }

  public static func shouldDeepScanChild(size: Int64, threshold: Int64) -> Bool {
    size >= threshold
  }
}
