import Foundation

public enum ScanContentLevel: String, Codable, Sendable {
  /// Sizes and names only — chart / prefetch preview.
  case light
  /// Full metadata for sidebar, filters, and search.
  case full
}
