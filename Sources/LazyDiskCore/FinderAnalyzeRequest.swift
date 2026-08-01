import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// Parses file URLs from Finder Services pasteboards and filename lists.
public enum FinderAnalyzeRequest {
  public static func urls(fromFilenames filenames: [String]) -> [URL] {
    filenames
      .map { ($0 as NSString).expandingTildeInPath }
      .filter { !$0.isEmpty }
      .map { URL(fileURLWithPath: $0, isDirectory: true) }
  }

  public static func urls(fromPropertyList list: Any?) -> [URL] {
    guard let list else { return [] }
    if let strings = list as? [String] {
      return urls(fromFilenames: strings)
    }
    if let string = list as? String {
      return urls(fromFilenames: [string])
    }
    return []
  }

  #if canImport(AppKit)
  public static func urls(from pasteboard: NSPasteboard) -> [URL] {
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
      .urlReadingFileURLsOnly: true,
    ]) as? [URL], !urls.isEmpty {
      return urls
    }

    if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) {
      let fromList = urls(fromPropertyList: filenames)
      if !fromList.isEmpty { return fromList }
    }

    if let text = pasteboard.string(forType: .string)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      text.hasPrefix("/") {
      return urls(fromFilenames: [text])
    }

    return []
  }
  #endif
}
