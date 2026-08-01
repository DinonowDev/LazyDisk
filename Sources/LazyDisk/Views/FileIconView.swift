import AppKit
import SwiftUI

struct FileIconView: View {
    let url: URL
    var size: CGFloat = 32

    private static let iconCache = NSCache<NSString, NSImage>()

    var body: some View {
        Image(nsImage: cachedIcon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var cachedIcon: NSImage {
        let key = url.path as NSString
        if let cached = Self.iconCache.object(forKey: key) {
            return cached
        }
        let image: NSImage
        if url.path == "/" || url.lastPathComponent.isEmpty {
            image = NSWorkspace.shared.icon(for: .folder)
        } else {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
        Self.iconCache.setObject(image, forKey: key)
        return image
    }
}
