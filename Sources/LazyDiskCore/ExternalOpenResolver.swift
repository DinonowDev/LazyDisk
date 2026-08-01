import Foundation

/// Resolves Finder / Services / `open -a` requests into a folder to analyze in LazyDisk.
public enum ExternalOpenResolver {
  public struct VolumeRoot: Sendable {
    public let id: String
    public let scanRoot: URL

    public init(id: String, scanRoot: URL) {
      self.id = id
      self.scanRoot = scanRoot
    }
  }

  /// Folder to scan: directories as-is; files → parent folder.
  public static func analyzeTarget(for url: URL) -> URL {
    let resolved = PathUtils.resolved(url)
    if let values = try? resolved.resourceValues(forKeys: [.isDirectoryKey]),
       values.isDirectory == true {
      return resolved
    }
    if resolved.hasDirectoryPath {
      return resolved
    }
    return resolved.deletingLastPathComponent()
  }

  public static func containingVolumeID(
    for target: URL,
    volumes: [VolumeRoot]
  ) -> String? {
    volumes.first { PathUtils.isWithinVolume(target, scanRoot: $0.scanRoot) }?.id
  }

  /// Parses `lazydisk://analyze/Users/foo` or `lazydisk://open?path=/Users/foo`.
  public static func urls(from customSchemeURL: URL) -> [URL] {
    guard customSchemeURL.scheme?.lowercased() == "lazydisk" else { return [] }

    if customSchemeURL.host?.lowercased() == "open",
       let components = URLComponents(url: customSchemeURL, resolvingAgainstBaseURL: false),
       let path = components.queryItems?.first(where: { $0.name == "path" })?.value,
       !path.isEmpty {
      return [URL(fileURLWithPath: path, isDirectory: true)]
    }

    var path = customSchemeURL.path
    if path.isEmpty, let host = customSchemeURL.host, !host.isEmpty, host != "open" {
      path = "/\(host)"
    }
    if path.isEmpty { return [] }
    return [URL(fileURLWithPath: path, isDirectory: true)]
  }
}
