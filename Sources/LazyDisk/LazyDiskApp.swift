import AppKit
import SwiftUI

@main
struct LazyDiskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = DiskBrowserViewModel()

    init() {
        _ = CLICommandRunner.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, minHeight: 750)
                .onOpenURL { url in
                    if url.isFileURL {
                        viewModel.analyzeExternalURLs([url])
                    } else {
                        let custom = ExternalOpenResolver.urls(from: url)
                        viewModel.analyzeExternalURLs(custom.isEmpty ? [url] : custom)
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(replacing: .appInfo) {
                Button(L10n.menuAbout) {
                    viewModel.showAbout = true
                }
            }

            CommandGroup(after: .appSettings) {
                Button(L10n.preferences) {
                    viewModel.showPreferences = true
                }
                .keyboardShortcut(",", modifiers: .command)

                Button(L10n.menuDonate) {
                    viewModel.showDonation = true
                }
            }

            CommandGroup(after: .help) {
                Button(L10n.menuDonate) {
                    viewModel.showDonation = true
                }
            }

            CommandMenu(L10n.menuNavigate) {
                Button(L10n.goUp) {
                    viewModel.navigateUp()
                }
                .keyboardShortcut(.delete, modifiers: [])

                Button(L10n.refresh) {
                    viewModel.refreshCurrentFolder()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button(L10n.rescan) {
                    viewModel.rescanVolume()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandMenu(L10n.prefDisplay) {
                Picker(L10n.prefChartStyle, selection: Binding(
                    get: { viewModel.chartStyle },
                    set: { viewModel.setChartStyle($0) }
                )) {
                    ForEach(ChartStyle.selectableCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Picker(L10n.menuSortBy, selection: $viewModel.sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            }

            CommandMenu(L10n.menuFile) {
                Button(L10n.quickLook) {
                    viewModel.quickLookSelection()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button(L10n.addToCollector) {
                    viewModel.selectedItems.forEach { viewModel.addToCollector($0) }
                }
                .keyboardShortcut("d", modifiers: .command)

                Button(L10n.collectorClear) {
                    viewModel.clearCollector()
                }

                Divider()

                Button(L10n.exportCSV) {
                    viewModel.exportCurrentFolderCSV()
                }

                Button(L10n.exportJSON) {
                    viewModel.exportCurrentFolderJSON()
                }

                Divider()

                Button(L10n.selectAll) {
                    viewModel.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button(L10n.deleteAction) {
                    viewModel.requestDelete()
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarStorageView(viewModel: viewModel)
        } label: {
            Image(systemName: "externaldrive.fill")
        }
    }
}
