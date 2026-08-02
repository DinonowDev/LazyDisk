import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        HStack(spacing: 0) {
            FeaturePanelSidebar(selectedPanel: $viewModel.activePanel)

            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.5)

                Group {
                    activePanelContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                if viewModel.activePanel.showsCollector {
                    CollectorView()
                }
            }
        }
        .background(chartBackgroundColor)
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
        .alert(L10n.exportDone, isPresented: .init(
            get: { viewModel.exportMessage != nil },
            set: { if !$0 { viewModel.exportMessage = nil } }
        )) {
            Button(L10n.ok) { viewModel.exportMessage = nil }
        }
    }

    @ViewBuilder
    private var activePanelContent: some View {
        switch viewModel.activePanel {
        case .browser:
            browserContent
        case .cleanup:
            CleanupSuggestionsView()
        case .duplicates:
            DuplicateFinderView()
        case .history:
            ScanDiffView()
        case .dev:
            DevModeView()
        case .goal:
            FreeSpaceGoalView()
        }
    }

    private var browserContent: some View {
        HSplitView {
            mainPanel
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
                .clipped()

            VStack(spacing: 0) {
                recentBookmarksBar
                FolderSidebarView()
            }
            .frame(
                minWidth: BrowserSidebarMetrics.professionalMinWidth,
                idealWidth: BrowserSidebarMetrics.clamp(
                    viewModel.browserSidebarWidth,
                    mode: .professional
                ),
                maxWidth: BrowserSidebarMetrics.professionalMaxWidth
            )
            .layoutPriority(1)
            .clipped()
            .trackPanelWidth { viewModel.saveSidebarWidth($0) }
        }
        .clipped()
    }

    private var recentBookmarksBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if !viewModel.bookmarks.isEmpty {
                    ForEach(viewModel.bookmarks) { bookmark in
                        Button(bookmark.name) {
                            viewModel.navigate(to: bookmark.url)
                            viewModel.activePanel = .browser
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.1)))
                    }
                }
                ForEach(viewModel.recentFolders.prefix(5), id: \.path) { url in
                    Button((url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)) {
                        viewModel.navigate(to: url)
                        viewModel.activePanel = .browser
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var chartBackgroundColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("LazyDisk")
                        .font(.system(size: 15, weight: .bold))
                    if let volume = viewModel.selectedVolume {
                        Text(volumeStatusText(volume))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Picker(L10n.volumeLabel, selection: volumeBinding) {
                ForEach(viewModel.volumes) { volume in
                    HStack {
                        Image(systemName: volume.volumeIcon)
                        VStack(alignment: .leading) {
                            Text(volume.name)
                            Text("\(volume.formattedUsed) / \(volume.formattedTotal)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(Optional(volume))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)

            Spacer()

            if viewModel.isLoading {
                HStack(spacing: 8) {
                    CompactProgressView(size: 14)
                    Text(viewModel.scanProgress.isEmpty ? L10n.analyzing : viewModel.scanProgress)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
            }

            Menu {
                Button(L10n.exportCSV) { viewModel.exportCurrentFolderCSV() }
                Button(L10n.exportJSON) { viewModel.exportCurrentFolderJSON() }
                Divider()
                Button(L10n.addBookmark) { viewModel.toggleBookmark() }
                Button(L10n.rebuildSearchIndex) { viewModel.rebuildSearchIndex() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)

            Button {
                viewModel.rescanVolume()
            } label: {
                Label(L10n.rescan, systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(viewModel.isLoading)

            permissionHint
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func volumeStatusText(_ volume: VolumeInfo) -> String {
        "\(volume.formattedUsed) \(L10n.menuBarUsed) · \(volume.formattedAvailable) \(L10n.menuBarFree)"
    }

    private var volumeBinding: Binding<VolumeInfo?> {
        Binding(
            get: { viewModel.selectedVolume },
            set: { if let vol = $0 { viewModel.selectVolume(vol) } }
        )
    }

    private var permissionHint: some View {
        Button {
            viewModel.showPermissions()
        } label: {
            Label(
                viewModel.allPermissionsGranted ? L10n.permissionsOK : L10n.permissions,
                systemImage: viewModel.allPermissionsGranted ? "checkmark.shield.fill" : "lock.shield"
            )
            .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.borderless)
        .foregroundStyle(viewModel.allPermissionsGranted ? .green : .secondary)
    }

    private var mainPanel: some View {
        chartPanel
            .animation(.easeInOut(duration: 0.25), value: viewModel.navigationAnimationID)
    }

    private var chartPanel: some View {
        ChartPanelView(centerFolderName: centerFolderName)
    }

    private var centerFolderName: String {
        if viewModel.isAtVolumeRoot {
            return viewModel.selectedVolume?.name ?? L10n.diskLabel
        }
        guard let path = viewModel.currentPath else { return L10n.diskLabel }
        let name = path.lastPathComponent
        return name.isEmpty ? path.path : name
    }

    private func hintItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.tertiary)
    }
}

// MARK: - Chart Panel

private struct ChartPanelView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    let centerFolderName: String

    @State private var chartHoverID: UUID?

    private var effectiveChartHover: UUID? {
        chartHoverID ?? viewModel.hoveredID
    }

    var body: some View {
        VStack(spacing: 0) {
            DiskOverviewHeader(
                volume: viewModel.selectedVolume,
                currentTotal: viewModel.totalSize,
                isLoading: viewModel.isLoading
            )

            ChartLegendView(
                items: viewModel.chartItems,
                totalSize: viewModel.displayTotalSize,
                hoveredID: effectiveChartHover,
                onHover: setChartHover,
                onSelect: { item in
                    viewModel.handleChartItemSelection(item)
                }
            )
            .padding(.top, 12)
            .padding(.bottom, 16)

            ZStack(alignment: chartPickerAlignment) {
                Group {
                    if viewModel.chartStyle == .sunburst {
                        SunburstChartView(
                            segments: viewModel.sunburstSegments,
                            totalSize: viewModel.displayTotalSize,
                            centerTitle: centerFolderName,
                            centerSubtitle: viewModel.isLoading ? L10n.scanning : nil,
                            layoutConfig: viewModel.interfaceMode == .simple
                                ? .daisyDisk
                                : .standard,
                            hoveredID: effectiveChartHover,
                            onHover: setChartHover,
                            onSelect: chartItemSelected,
                            onAddToCollector: { item in
                                viewModel.addToCollector(item)
                            }
                        )
                    } else if viewModel.chartStyle == .treemap {
                        TreemapChartView(
                            items: viewModel.chartItems,
                            childrenByParentPath: viewModel.chartChildMap,
                            totalSize: viewModel.displayTotalSize,
                            hoveredID: effectiveChartHover,
                            onHover: setChartHover,
                            onSelect: chartItemSelected,
                            onAddToCollector: { item in
                                viewModel.addToCollector(item)
                            }
                        )
                    } else {
                        RoseChartView(
                            items: viewModel.chartItems,
                            totalSize: viewModel.displayTotalSize,
                            centerTitle: centerFolderName,
                            centerSubtitle: viewModel.isLoading ? L10n.scanning : nil,
                            hoveredID: effectiveChartHover,
                            onHover: setChartHover,
                            onSelect: chartItemSelected,
                            onAddToCollector: { item in
                                viewModel.addToCollector(item)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.easeInOut(duration: 0.25), value: viewModel.chartStyle)

                ChartStylePicker(selection: Binding(
                    get: { viewModel.chartStyle },
                    set: { viewModel.setChartStyle($0) }
                ))
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            chartHint
        }
        .background { chartBackground }
        .onChange(of: viewModel.hoveredID) { newValue in
            if newValue != nil { chartHoverID = nil }
        }
        .onChange(of: viewModel.navigationAnimationID) { _ in
            chartHoverID = nil
        }
        .task(id: chartChildrenRefreshKey) {
            viewModel.refreshChartChildren()
        }
    }

    private var chartChildrenRefreshKey: String {
        let path = viewModel.currentPath.map { PathUtils.resolved($0).path } ?? ""
        return "\(viewModel.chartStyle.rawValue)-\(viewModel.navigationAnimationID.uuidString)-\(path)"
    }

    private var chartPickerAlignment: Alignment {
        L10n.isRTL ? .topLeading : .topTrailing
    }

    private func setChartHover(_ id: UUID?) {
        chartHoverID = id
    }

    private func chartItemSelected(_ item: DiskItem) {
        viewModel.handleChartItemSelection(item)
    }

    private var chartBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color.accentColor.opacity(0.04), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
        }
    }

    private var chartHint: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                hintItem(icon: "hand.tap.fill", text: L10n.chartHintDrillDown)
                hintItem(icon: "info.circle", text: L10n.chartHintSelect)
                hintItem(icon: "arrow.down.to.line", text: L10n.addToCollector)
                hintItem(icon: "space", text: L10n.hintSpace)
                hintItem(icon: "delete.left.fill", text: L10n.hintBackspace)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 14)
    }

    private func hintItem(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.tertiary)
    }
}
