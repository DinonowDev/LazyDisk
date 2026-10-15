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

    private var showChartLoadingOverlay: Bool {
        viewModel.isBrowserChartLoading
    }

    private var showsSunburstChart: Bool {
        guard viewModel.chartStyle == .sunburst else { return false }
        guard !showChartLoadingOverlay else { return false }
        return !viewModel.sunburstSegments.isEmpty
    }

    private var showsRoseChart: Bool {
        viewModel.chartStyle != .sunburst
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                chartPanel
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(0)
                    .clipped()

                SimpleFolderSidebarView(
                    hoveredID: effectiveChartHover,
                    onHover: setChartHover,
                    chartStyles: simpleChartStyles,
                    chartStyle: Binding(
                        get: { viewModel.chartStyle },
                        set: { viewModel.setChartStyle($0) }
                    )
                )
                .frame(
                    minWidth: BrowserSidebarMetrics.simpleMinWidth,
                    idealWidth: BrowserSidebarMetrics.clamp(
                        viewModel.browserSidebarWidth,
                        mode: .simple
                    ),
                    maxWidth: BrowserSidebarMetrics.simpleMaxWidth
                )
                .layoutPriority(1)
                .clipped()
                .trackPanelWidth { viewModel.saveSidebarWidth($0) }
            }
            .clipped()

            CollectorView()
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
                viewModel.refreshChartChildrenIfNeeded()
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
                    .allowsHitTesting(!showChartLoadingOverlay)
                }

                if showChartLoadingOverlay {
                    ChartChildrenScanOverlay(
                        totalSize: viewModel.displayTotalSize,
                        progress: viewModel.browserChartScanProgress
                    )
                }
            } else if showsRoseChart {
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
                .allowsHitTesting(!showChartLoadingOverlay)

                if showChartLoadingOverlay {
                    ChartChildrenScanOverlay(
                        totalSize: viewModel.displayTotalSize,
                        progress: viewModel.browserChartScanProgress
                    )
                }
            } else if showChartLoadingOverlay {
                ChartChildrenScanOverlay(
                    totalSize: viewModel.displayTotalSize,
                    progress: viewModel.browserChartScanProgress
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: viewModel.chartStyle)
        .animation(.easeInOut(duration: 0.2), value: showChartLoadingOverlay)
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
        let path = viewModel.currentPath.map { PathUtils.resolved($0).path } ?? ""
        return "simple-\(viewModel.chartStyle.rawValue)-\(viewModel.navigationAnimationID.uuidString)-\(path)"
    }

    private func setChartHover(_ id: UUID?) {
        chartHoverID = id
    }

    private func chartItemSelected(_ item: DiskItem) {
        viewModel.handleChartItemSelection(item)
    }
}
