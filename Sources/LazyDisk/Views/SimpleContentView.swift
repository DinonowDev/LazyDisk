import SwiftUI

struct SimpleContentView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @State private var chartHoverID: UUID?

    private let simpleChartStyles: [ChartStyle] = [.rose, .sunburst]

    private var effectiveChartHover: UUID? {
        chartHoverID ?? viewModel.hoveredID
    }

    private var centerFolderName: String {
        if viewModel.isAtVolumeRoot {
            return viewModel.selectedVolume?.name ?? L10n.diskLabel
        }
        guard let path = viewModel.currentPath else { return L10n.diskLabel }
        let name = path.lastPathComponent
        return name.isEmpty ? path.path : name
    }

    private var showSunburstLoading: Bool {
        viewModel.chartStyle == .sunburst && viewModel.isChartChildrenLoading
    }

    /// Progressive sunburst preview while deeper rings are still loading.
    private var showsChartPreviewWhileLoading: Bool {
        showSunburstLoading
    }

    private var showsSunburstChart: Bool {
        guard viewModel.chartStyle == .sunburst else { return false }
        return !viewModel.sunburstSegments.isEmpty || showsChartPreviewWhileLoading
    }

    var body: some View {
        HSplitView {
            chartPanel
                .frame(minWidth: 480)
                .layoutPriority(1)

            SimpleFolderSidebarView(
                hoveredID: effectiveChartHover,
                onHover: setChartHover,
                chartStyles: simpleChartStyles,
                chartStyle: Binding(
                    get: { viewModel.chartStyle },
                    set: { viewModel.setChartStyle($0) }
                )
            )
            .frame(width: viewModel.browserSidebarWidth)
            .frame(minWidth: 260, maxWidth: 400)
            .layoutPriority(0)
            .trackPanelWidth { viewModel.saveSidebarWidth($0) }
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(Color(nsColor: .windowBackgroundColor))
        .keyboardShortcuts()
        .onAppear { viewModel.refreshPermissionsDeferred() }
        .onDeleteCommand { viewModel.requestDelete() }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationSheet()
                .environmentObject(viewModel)
        }
        .alert(L10n.errorTitle, isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.ok) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task(id: chartChildrenRefreshKey) {
            if viewModel.chartStyle == .sunburst {
                viewModel.refreshChartChildren()
            }
        }
    }

    private var chartPanel: some View {
        ZStack {
            chartBackground

            if viewModel.chartStyle == .sunburst {
                if showsSunburstChart {
                    SunburstChartView(
                        segments: viewModel.sunburstSegments,
                        totalSize: viewModel.displayTotalSize,
                        centerTitle: centerFolderName,
                        centerSubtitle: viewModel.isLoading ? L10n.scanning : nil,
                        appearance: .daisyDisk,
                        layoutConfig: .daisyDisk,
                        hoveredID: effectiveChartHover,
                        onHover: setChartHover,
                        onSelect: chartItemSelected,
                        onCenterTap: {
                            if !viewModel.isAtVolumeRoot {
                                viewModel.navigateUp()
                            }
                        },
                        onAddToCollector: { viewModel.addToCollector($0) }
                    )
                    .padding(24)
                    .opacity(showsChartPreviewWhileLoading ? 0.28 : 1)
                    .allowsHitTesting(!showSunburstLoading)
                }

                if showSunburstLoading {
                    ChartChildrenScanOverlay(
                        totalSize: viewModel.displayTotalSize,
                        progress: viewModel.chartChildrenScanProgress
                    )
                }
            } else {
                RoseChartView(
                    items: viewModel.chartItems,
                    totalSize: viewModel.displayTotalSize,
                    centerTitle: centerFolderName,
                    centerSubtitle: viewModel.isLoading ? L10n.scanning : nil,
                    hoveredID: effectiveChartHover,
                    onHover: setChartHover,
                    onSelect: chartItemSelected,
                    onAddToCollector: { viewModel.addToCollector($0) }
                )
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: viewModel.chartStyle)
        .animation(.easeInOut(duration: 0.2), value: showSunburstLoading)
    }

    private var chartBackground: some View {
        ZStack {
            Color(white: 0.06)
            if viewModel.chartStyle == .sunburst {
                RadialGradient(
                    colors: [Color.white.opacity(0.03), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
    }

    private var chartChildrenRefreshKey: String {
        "simple-\(viewModel.chartStyle.rawValue)-\(viewModel.navigationAnimationID.uuidString)-\(viewModel.chartCacheRevision)"
    }

    private func setChartHover(_ id: UUID?) {
        chartHoverID = id
    }

    private func chartItemSelected(_ item: DiskItem) {
        guard !item.isVirtual else { return }
        if item.isDirectory {
            viewModel.openItem(item)
        }
    }
}
