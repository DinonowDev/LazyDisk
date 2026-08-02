import Foundation
import LazyDiskCore

actor SizeIndexCoordinator {
    static let shared = SizeIndexCoordinator()

    private var persistTask: Task<Void, Never>?
    private var activeVolumeID: String?

    func warm(for volume: VolumeInfo) async {
        activeVolumeID = volume.id
        guard AppPreferences.load().usePersistentCache else { return }

        let sizes = await PersistentSizeIndexStore.shared.load(volumeID: volume.id)
        guard !sizes.isEmpty else { return }
        await DirectorySizeIndex.shared.importSizes(sizes)
    }

    func schedulePersist(for volumeID: String?) {
        guard AppPreferences.load().usePersistentCache else { return }
        guard let volumeID else { return }

        activeVolumeID = volumeID
        persistTask?.cancel()
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            let sizes = await DirectorySizeIndex.shared.sizesSnapshot()
            await PersistentSizeIndexStore.shared.save(volumeID: volumeID, sizes: sizes)
        }
    }

    func invalidate(prefix: String, volumeID: String?) async {
        await DirectorySizeIndex.shared.invalidate(prefix: prefix)
        schedulePersist(for: volumeID ?? activeVolumeID)
    }

    func clear(volumeID: String?) async {
        persistTask?.cancel()
        await DirectorySizeIndex.shared.clear()
        if let volumeID {
            await PersistentSizeIndexStore.shared.clear(volumeID: volumeID)
        } else {
            await PersistentSizeIndexStore.shared.clearAll()
        }
    }
}
