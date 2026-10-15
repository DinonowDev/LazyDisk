// DiskBrowserViewModel+RestrictedScan.swift — Admin helper / FDA retry for restricted paths.
import Foundation
import LazyDiskCore

extension DiskBrowserViewModel {
    func refreshRestrictedScanState() async {
        let events = await RestrictedScanCoordinator.shared.allEvents()
        restrictedScanEvents = events
    }

    func reconcileRestrictedPathsAfterScan() async {
        await refreshRestrictedScanState()
        let events = restrictedScanEvents
        guard !events.isEmpty else { return }

        let prefs = AppPreferences.load()
        privilegedHelperScanProgress = nil
        let sizes = await AdminScanGateway.retrySizing(
            for: events,
            skipHiddenFiles: !prefs.showHiddenFiles,
            listedChildren: { url in
                let urls = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: prefs.showHiddenFiles ? [] : [.skipsHiddenFiles]
                )) ?? []
                return urls.filter {
                    (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
            },
            onPrivilegedProgress: { path, progress in
                Task { @MainActor in
                    self.privilegedHelperScanProgress = progress
                    let name = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
                    self.scanProgress = L10n.scanFolderNamed(name.isEmpty ? path : name)
                    self.scanProgressFraction = progress.finished ? 0.95 : min(0.9, self.scanProgressFraction + 0.02)
                }
            }
        )
        privilegedHelperScanProgress = nil

        if !sizes.isEmpty {
            let applied = await RestrictedSizeApplier.apply(
                sizes: sizes,
                scanRoot: currentPath ?? selectedVolume?.scanRoot,
                entries: entries
            )
            entries = applied.entries
            await RestrictedScanCoordinator.shared.remove(paths: applied.resolvedPaths)
            invalidateAllDerivedCaches()
            refreshChartChildrenIfNeeded()
            scheduleSizeIndexPersist()
        }

        await refreshRestrictedScanState()
    }

    func installAdminHelperAndRetryScan() async {
        guard !isInstallingAdminHelper else { return }
        isInstallingAdminHelper = true
        defer { isInstallingAdminHelper = false }

        if PermissionsService.isRunningAsAppBundle {
            do {
                try PrivilegedHelperInstaller.install()
                if PrivilegedHelperInstaller.isHelperJobRegistered()
                    || PrivilegedScanClient.shared.isHelperReachable() {
                    exportMessage = L10n.adminHelperInstalled
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            PermissionsService.requestAll()
        }

        await MainActor.run {
            refreshPermissions()
        }
        await retryRestrictedScanOnly()
    }

    func retryRestrictedScanOnly() async {
        await reconcileRestrictedPathsAfterScan()
    }

    func refreshScanMetricsForCurrentFolder() async {
        guard let currentPath else {
            lastScanMetrics = nil
            return
        }
        let path = PathUtils.resolved(currentPath).path
        lastScanMetrics = await DirectorySizeIndex.shared.scanMetrics(for: path)
    }
}
