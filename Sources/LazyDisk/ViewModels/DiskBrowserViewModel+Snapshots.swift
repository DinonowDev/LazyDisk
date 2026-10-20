import Foundation
import LazyDiskCore

struct SnapshotBrowserState: Equatable {
    var volumePath: String
    var items: [DiskItem]
    var totalBytes: Int64
    var sizeIsEstimate: Bool
}

extension DiskBrowserViewModel {
    var chartCenterTitle: String {
        if isShowingSnapshots { return L10n.localSnapshots }
        if isAtVolumeRoot { return selectedVolume?.name ?? L10n.diskLabel }
        guard let path = currentPath else { return L10n.diskLabel }
        let name = path.lastPathComponent
        return name.isEmpty ? path.path : name
    }

    var chartCenterSubtitle: String? {
        if isLoading { return L10n.scanning }
        if snapshotBrowser?.sizeIsEstimate == true { return L10n.snapshotSizeEstimate }
        return nil
    }

    func openSnapshotBrowser() {
        guard let volume = selectedVolume else { return }
        let snapshots = APFSSnapshotStore.list(volumePath: volume.scanRoot.path)
            .filter { APFSSnapshotName.isDeletable($0.name) }
        let group = APFSSnapshotGroupBuilder.make(
            snapshots: snapshots,
            purgeableCapacity: volume.purgeableCapacity
        )
        guard !group.snapshots.isEmpty else {
            closeSnapshotBrowser()
            return
        }
        snapshotBrowser = SnapshotBrowserState(
            volumePath: volume.scanRoot.path,
            items: VolumeUsageReconciler.snapshotItems(volumePath: volume.scanRoot.path, group: group),
            totalBytes: group.totalBytes,
            sizeIsEstimate: group.sizeIsEstimate
        )
        activePanel = .browser
        clearSmartCollection()
        closeDetailPanel()
        invalidateAllDerivedCaches()
    }

    func closeSnapshotBrowser() {
        guard snapshotBrowser != nil else { return }
        snapshotBrowser = nil
        closeDetailPanel()
        invalidateAllDerivedCaches()
    }

    func requestSnapshotDelete(_ item: DiskItem) {
        guard item.role == .snapshot, APFSSnapshotName.isDeletable(item.url.lastPathComponent) else { return }
        pendingSnapshotDeleteName = item.url.lastPathComponent
        pendingSnapshotDeleteTitle = item.displayName
        showSnapshotDeleteConfirmation = true
    }

    func confirmSnapshotDelete() {
        guard let name = pendingSnapshotDeleteName, let volume = selectedVolume else { return }
        let volumePath = volume.scanRoot.path
        showSnapshotDeleteConfirmation = false
        pendingSnapshotDeleteName = nil

        Task {
            do {
                try await PrivilegedScanClient.shared.deleteLocalSnapshot(name: name, volumePath: volumePath)
                await refreshAfterSnapshotChange()
            } catch let error as PrivilegedScanClientError where error == .unavailable || error == .connectionInterrupted {
                errorMessage = L10n.snapshotDeleteNeedsHelper
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain || nsError.localizedDescription.isEmpty {
                    errorMessage = L10n.snapshotDeleteNeedsHelper
                } else if PrivilegedScanClient.shared.isHelperReachable() {
                    errorMessage = nsError.localizedDescription
                } else {
                    errorMessage = L10n.snapshotDeleteNeedsHelper
                }
            }
        }
    }

    func refreshAfterSnapshotChange() async {
        let vols = await scanner.listVolumes()
        volumes = vols
        if let current = selectedVolume,
           let updated = vols.first(where: { $0.id == current.id }) {
            selectedVolume = updated
        }
        guard let volume = selectedVolume, isAtVolumeRoot else {
            closeSnapshotBrowser()
            return
        }
        let real = entries.filter { !$0.isVirtual }
        entries = await scanner.reconcileWithVolumeUsage(items: real, volume: volume, atVolumeRoot: true)
        invalidateAllDerivedCaches()
        if snapshotBrowser != nil {
            openSnapshotBrowser()
        }
    }

    func navigateFromBreadcrumb(_ url: URL) {
        if VirtualDiskPath.isSnapshotGroup(url) {
            openSnapshotBrowser()
            return
        }
        closeSnapshotBrowser()
        navigate(to: url)
    }
}
