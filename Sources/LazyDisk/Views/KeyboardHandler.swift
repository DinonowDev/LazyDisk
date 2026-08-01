import AppKit
import SwiftUI

struct KeyboardHandler: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyboardNSView {
        let view = KeyboardNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyboardNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
    }
}

final class KeyboardNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installMonitor()
    }

    override func removeFromSuperview() {
        removeMonitor()
        super.removeFromSuperview()
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else { return event }
            if self.isTextInputActive() { return event }
            if self.onKeyDown?(event) == true { return nil }
            return event
        }
    }

    private func isTextInputActive() -> Bool {
        guard let responder = window?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct KeyboardShortcutsModifier: ViewModifier {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    func body(content: Content) -> some View {
        content
            .background(
                KeyboardHandler { event in handleKey(event) }
                    .frame(width: 0, height: 0)
            )
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard viewModel.appPhase == .ready else { return false }
        guard !viewModel.isSearchFieldFocused else { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if flags.contains(.command), key == "a" {
            viewModel.selectAll()
            return true
        }

        if flags.contains(.command), key == "d" {
            viewModel.selectedItems.forEach { viewModel.addToCollector($0) }
            return true
        }

        if flags.isEmpty {
            switch event.keyCode {
            case 49: // Space
                viewModel.quickLookSelection()
                return true
            case 36: // Return
                viewModel.handleEnterKey()
                return true
            case 51: // Backspace
                viewModel.navigateUp()
                return true
            case 126: // Up
                viewModel.moveKeyboardFocus(delta: -1)
                return true
            case 125: // Down
                viewModel.moveKeyboardFocus(delta: 1)
                return true
            case 123: // Left — go up folder
                viewModel.navigateUp()
                return true
            case 124: // Right — open focused folder
                if viewModel.keyboardFocusedIndex < viewModel.filteredEntries.count {
                    let item = viewModel.filteredEntries[viewModel.keyboardFocusedIndex]
                    if item.isDirectory { viewModel.openItem(item) }
                }
                return true
            default:
                break
            }
        }

        return false
    }
}

extension View {
    func keyboardShortcuts() -> some View {
        modifier(KeyboardShortcutsModifier())
    }
}
