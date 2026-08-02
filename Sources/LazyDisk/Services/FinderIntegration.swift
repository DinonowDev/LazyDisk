import AppKit
import Foundation

extension Notification.Name {
  static let lazyDiskAnalyzeExternalURLs = Notification.Name("LazyDiskAnalyzeExternalURLs")
}

enum FinderIntegration {
  static func postAnalyzeRequest(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    NotificationCenter.default.post(name: .lazyDiskAnalyzeExternalURLs, object: urls)
  }

  static func registerServicesProvider() {
    NSApp.servicesProvider = FinderServicesProvider.shared
    NSUpdateDynamicServices()
  }
}

@objc(FinderServicesProvider)
final class FinderServicesProvider: NSObject, @unchecked Sendable {
  static let shared = FinderServicesProvider()

  @objc func analyzeWithLazyDisk(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
    let urls = FinderAnalyzeRequest.urls(from: pboard)
    guard !urls.isEmpty else { return }
    DispatchQueue.main.async {
      FinderIntegration.postAnalyzeRequest(urls)
    }
  }
}
