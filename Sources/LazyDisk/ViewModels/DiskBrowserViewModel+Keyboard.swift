// DiskBrowserViewModel+Keyboard.swift — Quick Look and keyboard navigation.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Quick Look & Keyboard

    func quickLookSelection() {
        let urls: [URL]
        if !selectedItems.isEmpty {
            urls = selectedItems.map(\.url)
        } else if keyboardFocusedIndex < browserListEntries.count {
            urls = [browserListEntries[keyboardFocusedIndex].url]
        } else {
            return
        }
        QuickLookService.preview(urls: urls.filter { !$0.path.isEmpty })
    }

    func handleEnterKey() {
        guard keyboardFocusedIndex < browserListEntries.count else { return }
        let item = browserListEntries[keyboardFocusedIndex]
        if item.isDirectory {
            openItem(item)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func moveKeyboardFocus(delta: Int) {
        guard !browserListEntries.isEmpty else { return }
        let newIndex = max(0, min(browserListEntries.count - 1, keyboardFocusedIndex + delta))
        setHoveredID(browserListEntries[newIndex].id, keyboardIndex: newIndex)
    }

    func revealInFinder(_ item: DiskItem) {
        guard !item.isVirtual else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

}
