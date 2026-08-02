import AppKit
import Foundation
import Quartz

enum QuickLookService {
    private static var activeDataSource: PreviewDataSource?

    @MainActor
    static func preview(urls: [URL]) {
        guard !urls.isEmpty else { return }

        guard let panel = QLPreviewPanel.shared() else { return }
        let dataSource = PreviewDataSource(urls: urls)
        activeDataSource = dataSource
        panel.dataSource = dataSource
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    @MainActor
    static func close() {
        QLPreviewPanel.shared()?.orderOut(nil)
    }
}

private final class PreviewDataSource: NSObject, QLPreviewPanelDataSource {
    let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        urls.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        urls[index] as NSURL
    }
}
