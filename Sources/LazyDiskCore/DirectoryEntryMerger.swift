import Foundation

public enum DirectoryEntryMerger {
  /// Merges a full directory listing with previously sized (possibly light) entries.
  public static func merge(
    fullListing: [DiskItem],
    sizedEntries: [DiskItem],
    sizeIndex: [String: Int64] = [:]
  ) -> [DiskItem] {
    let sizedByPath = Dictionary(
      uniqueKeysWithValues: sizedEntries.map { (PathUtils.resolved($0.url).path, $0) }
    )

    return fullListing.map { item in
      let path = PathUtils.resolved(item.url).path

      if let sized = sizedByPath[path] {
        var merged = item
        if sized.size > 0 {
          merged.size = sized.size
          merged.isScanning = false
        } else if let indexed = sizeIndex[path], indexed > 0 {
          merged.size = indexed
          merged.isScanning = false
        } else if item.isDirectory {
          merged.isScanning = sized.isScanning
        }
        return merged
      }

      if item.isDirectory, let indexed = sizeIndex[path], indexed > 0 {
        var merged = item
        merged.size = indexed
        merged.isScanning = false
        return merged
      }

      return item
    }
  }
}
