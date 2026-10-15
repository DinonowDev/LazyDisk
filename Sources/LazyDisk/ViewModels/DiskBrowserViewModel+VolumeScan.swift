// DiskBrowserViewModel+VolumeScan.swift — Initial volume scan and rescan orchestration.
import AppKit
import Foundation
import LazyDiskCore
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Welcome & Initial Scan

    func prepareWelcome() {
        startWorkspaceObserversIfNeeded()
        Task {
            let vols = await scanner.listVolumes()
            volumes = vols

            let session = SessionStateStore.load()
            if let lastID = session.lastVolumeID,
               let restored = vols.first(where: { $0.id == lastID }) {
                selectedVolume = restored
            } else if selectedVolume == nil {
                selectedVolume = vols.first(where: { $0.url.path == "/" }) ?? vols.first
            }

            if let volume = selectedVolume {
                await SizeIndexCoordinator.shared.warm(for: volume)
            }
            restartFilesystemMonitoring()

            if AppPreferences.load().autoResumeLastSession,
               await attemptAutoRestoreFromCache() {
                return
            }
        }
    }

    func canResumePreviousSession() async -> Bool {
        guard AppPreferences.load().usePersistentCache,
              let volume = selectedVolume ?? volumes.first else {
            return false
        }
        return await cache.hasRestorableVolumeRoot(volume.scanRoot)
    }

    func resumePreviousSession() {
        guard let volume = selectedVolume else { return }
        scanTask?.cancel()
        isLoading = true
        scanProgress = L10n.scanIncrementalChecking
        scanProgressFraction = 0.05
        withAnimation(.easeInOut(duration: 0.25)) {
            appPhase = .scanning
        }
        scanTask = Task {
            await hydrateSessionFromCache(volume: volume)
            await runGatedVolumeScan(volume: volume, preferIncremental: true)
        }
    }

    func startInitialScan() {
        guard let volume = selectedVolume else { return }

        if interfaceMode == .simple {
            chartStyle = .rose
        }

        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        scanProgressFraction = 0
        scanCurrentFolder = ""
        scanProgress = L10n.scanPreparing
        isInitialChartReady = false
        pendingFusedVolumeChart = nil
        clearChartChildMap()
        selectedIDs.removeAll()
        hoveredID = nil
        isLoading = true

        withAnimation(.easeInOut(duration: 0.25)) {
            appPhase = .scanning
        }

        scanTask = Task {
            let cancelFlag = ScanCancellationFlag()
            activeScanCancelFlag = cancelFlag
            let shouldCancel = cancelFlag.shouldCancelHandler()
            defer { endScanCancellationTracking() }
            await withTaskCancellationHandler {
                await RestrictedScanCoordinator.shared.clear()
                restrictedScanEvents = []
                await VolumeTreeScanCoordinator.shared.clear(volumeID: volume.id)
                await runGatedVolumeScan(volume: volume, preferIncremental: false, shouldCancel: shouldCancel)
            } onCancel: {
                cancelFlag.cancel()
            }
        }
    }

    func cancelScan() {
        cancelActiveNativeScan()
        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        scanTask = nil
        isLoading = false
        scanProgress = ""
        scanProgressFraction = 0
        scanCurrentFolder = ""
        appPhase = .welcome
    }

    func rescanVolume() {
        guard let volume = selectedVolume else { return }
        let previousPath = currentPath ?? volume.scanRoot

        scanTask?.cancel()
        prefetchTask?.cancel()
        incrementalRefreshTask?.cancel()
        cancelDepthPrefetch()
        isLoading = true
        scanProgress = L10n.scanIncrementalChecking
        scanTask = Task {
            await runGatedVolumeScan(volume: volume, preferIncremental: true)

            let resolvedPrevious = PathUtils.resolved(previousPath)
            let resolvedRoot = PathUtils.resolved(volume.scanRoot)
            if resolvedPrevious.path != resolvedRoot.path,
               PathUtils.isWithinVolume(resolvedPrevious, scanRoot: volume.scanRoot) {
                await performIncrementalScan(
                    at: resolvedPrevious,
                    volume: volume,
                    isVolumeRoot: false,
                    trackDetailedProgress: false
                )
            }
            guard !Task.isCancelled else { return }

            isLoading = false
            scanProgress = ""
            scanProgressFraction = 1
            applyPendingExternalAnalyzeIfNeeded()
            startBackgroundDepthPrefetch(scanRoot: volume.scanRoot)
        }
    }

    /// Full volume scan on the blocking splash (`ScanningView`); only then enter main UI.
    func runGatedVolumeScan(
        volume: VolumeInfo,
        preferIncremental: Bool,
        shouldCancel: (@Sendable () -> Bool)? = nil
    ) async {
        let cancelCheck = shouldCancel ?? activeScanCancelHandler()
        isGatedSplashVolumeScan = true
        Self.activeSplashScan = self
        defer {
            isGatedSplashVolumeScan = false
            if Self.activeSplashScan === self {
                Self.activeSplashScan = nil
            }
        }

        let scanRoot = PathUtils.resolved(volume.scanRoot)
        currentPath = scanRoot

        let cachedRoot = await cache.hasRestorableVolumeRoot(volume.scanRoot)
        let useIncrementalRefresh = preferIncremental && cachedRoot

        if useIncrementalRefresh {
            await performIncrementalScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true
            )
            guard !Task.isCancelled else { return }
            await prepareInitialChartPresentation(volume: volume, deferDisplayDepthPrefetch: false)
            guard !Task.isCancelled else { return }
            scanProgressFraction = VolumeSplashProgressPhases.complete()
            await enterAppAfterInitialScan(volume: volume)
        } else {
            await PersistentChartScanProgressStore.shared.clear(volumeID: volume.id)
            await scanner.clearSizeCache()
            await globalSearch.invalidateIndex(for: volume)
            didSignalVolumeSplashReady = false
            volumeSplashReadyContinuation = nil
            await performScan(
                at: volume.scanRoot,
                volume: volume,
                isVolumeRoot: true,
                trackDetailedProgress: true,
                shouldCancel: cancelCheck
            )
            guard !Task.isCancelled else { return }
            await prepareInitialChartPresentation(volume: volume, deferDisplayDepthPrefetch: false)
            guard !Task.isCancelled else { return }
            scanProgressFraction = VolumeSplashProgressPhases.complete()
            await enterAppAfterInitialScan(volume: volume)
        }

        guard !Task.isCancelled else { return }

        if !(await VolumeTreeScanCoordinator.shared.hasCompleteTreeScan(volumeID: volume.id)) {
            Task { [weak self] in
                await self?.ensureVolumeTreeIndexed(
                    volume: volume,
                    trackDetailedProgress: false,
                    shouldCancel: cancelCheck
                )
            }
        }
    }

    func waitForVolumeSplashReady() async {
        if didSignalVolumeSplashReady { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if didSignalVolumeSplashReady {
                continuation.resume()
                return
            }
            volumeSplashReadyContinuation = continuation
        }
    }

    func makeVolumeSplashReadyHandler(
        volume: VolumeInfo?,
        listedEntries: [DiskItem]
    ) -> (@Sendable (ChartTreeBuilder.BuildResult) -> Void)? {
        guard isGatedSplashVolumeScan, let volume else { return nil }
        return { [weak self] chart in
            DispatchQueue.main.async {
                self?.signalVolumeSplashReady(
                    chart: chart,
                    volume: volume,
                    listedEntries: listedEntries
                )
            }
        }
    }

    func signalVolumeSplashReady(
        chart: ChartTreeBuilder.BuildResult,
        volume: VolumeInfo,
        listedEntries: [DiskItem]
    ) {
        guard isGatedSplashVolumeScan, !didSignalVolumeSplashReady else { return }
        didSignalVolumeSplashReady = true
        let scanRoot = PathUtils.resolved(volume.scanRoot)
        pendingFusedVolumeChart = (chart, scanRoot, listedEntries)
        volumeSplashReadyContinuation?.resume()
        volumeSplashReadyContinuation = nil
    }

    func applySplashTreeIndexingProgress(filesScanned: Int) {
        let walk = ChartScanProgressMath.fileWalkFraction(filesScanned: filesScanned)
        let cap = ChartScanProgressMath.inFlightDisplayCap
        scanProgressFraction = VolumeSplashProgressPhases.sizing(
            normalizedSizingFraction: min(walk / cap, 1),
            published: scanProgressFraction
        )
    }

    /// Builds the deep path-size index used for instant folder navigation (DaisyDisk-style).
    func ensureVolumeTreeIndexed(
        volume: VolumeInfo,
        trackDetailedProgress: Bool,
        shouldCancel: (@Sendable () -> Bool)? = nil
    ) async {
        let cancelCheck = shouldCancel ?? activeScanCancelHandler()
        if await VolumeTreeScanCoordinator.shared.hasCompleteTreeScan(volumeID: volume.id) {
            return
        }

        let scanRoot = PathUtils.resolved(volume.scanRoot)
        let listed = await scanner.listDirectory(at: scanRoot)
        guard !Task.isCancelled else { return }

        let prefs = AppPreferences.load()
        let chartDepth = interfaceMode == .simple
            ? SunburstLayoutEngine.Config.daisyDisk.maxDepth
            : SunburstLayoutEngine.Config.standard.maxDepth

        if trackDetailedProgress {
            if isGatedSplashVolumeScan {
                scanProgressFraction = VolumeSplashProgressPhases.listed(published: scanProgressFraction)
            } else {
                scanProgressFraction = max(scanProgressFraction, 0.15)
            }
            scanProgress = L10n.scanIndexingTree
            scanCurrentFolder = ""
        }

        let skipHidden = !prefs.showHiddenFiles
        let parallelism = prefs.scanParallelism
        let reportSplashProgress = isGatedSplashVolumeScan && trackDetailedProgress
        let tree: FusedNativeScanResult? = await Task.detached(priority: .userInitiated) {
            NativeDirectoryScanner.volumeTreeScan(
                at: scanRoot,
                listedEntries: listed,
                chartMaxDepth: chartDepth,
                skipHiddenFiles: skipHidden,
                parallelism: parallelism,
                fullVolumeIndex: true,
                shouldCancel: cancelCheck,
                onPartial: { partial in
                    let sizes = partial.statsByPath.mapValues(\.size)
                    guard !sizes.isEmpty else { return }
                    Task { await DirectorySizeIndex.shared.importSizes(sizes) }
                    guard reportSplashProgress else { return }
                    let filesScanned = partial.filesScanned
                    DispatchQueue.main.async {
                        DiskBrowserViewModel.activeSplashScan?.applySplashTreeIndexingProgress(
                            filesScanned: filesScanned
                        )
                    }
                }
            )
        }.value
        guard !Task.isCancelled else { return }
        guard let tree else {
            if trackDetailedProgress {
                scanProgressFraction = 1
                scanProgress = L10n.scanIncrementalDone
                scanCurrentFolder = ""
            }
            return
        }

        if !tree.indexedPathSizes.isEmpty {
            await DirectorySizeIndex.shared.importSizes(tree.indexedPathSizes)
        }

        await RestrictedScanRegistrar.recordWalk(tree.sizingWalk)
        let restrictedRemaining = await RestrictedScanCoordinator.shared.allEvents()
        if restrictedRemaining.isEmpty {
            await VolumeTreeScanCoordinator.shared.markComplete(
                volumeID: volume.id,
                scanRoot: volume.scanRoot
            )
        }
        scheduleSizeIndexPersist()

        let resolvedCurrent = currentPath.map(PathUtils.resolved(_:))
        if isAtVolumeRoot, resolvedCurrent?.path == scanRoot.path {
            await storeVolumeChartChildMap(
                volumeID: volume.id,
                buildResult: tree.chartResult,
                root: scanRoot,
                listedEntries: listed
            )
            if !isGatedSplashVolumeScan {
                applyFusedChartFromVolumeScan(tree.chartResult, root: scanRoot, listedEntries: listed)
            }
            entries = sortOrder.sort(
                DirectorySizeWalker.applySizes(to: listed, walkResult: tree.sizingWalk)
            )
            invalidateAllDerivedCaches()
            await cache.set(
                scanRoot,
                entries: entries,
                isVolumeRoot: true,
                contentLevel: .full
            )
        }

        if trackDetailedProgress {
            scanProgressFraction = 1
            scanProgress = L10n.scanIncrementalDone
            scanCurrentFolder = ""
        }
    }

    func enterAppAfterInitialScan(volume: VolumeInfo) async {
        guard !Task.isCancelled else { return }

        startSearchIndexBuild()
        saveScanSnapshot(volume: volume)
        SessionStateStore.save(volumeID: volume.id, path: currentPath ?? volume.scanRoot)

        if !isInitialChartReady {
            await prepareInitialChartPresentation(volume: volume, deferDisplayDepthPrefetch: true)
            guard !Task.isCancelled else { return }
        }

        withAnimation(.easeInOut(duration: 0.35)) {
            appPhase = .ready
        }
        isLoading = false
        scanProgress = ""
        scanProgressFraction = 1
        loadedFromCache = false

        applyPendingExternalAnalyzeIfNeeded()
        restartFilesystemMonitoring()

        startSmartPrefetch(chartMap: chartChildMap)
        startBackgroundDepthPrefetch(scanRoot: volume.scanRoot)
    }
}
