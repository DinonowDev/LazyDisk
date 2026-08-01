import Foundation

extension DiskItem {
    var displayName: String {
        if isVirtual { return name }
        if isHidden && !name.hasPrefix(".") { return ".\(name)" }
        return name
    }

    var formattedModifiedDate: String {
        guard let modifiedDate else { return "—" }
        return DiskItem.modifiedDateFormatter.string(from: modifiedDate)
    }

    func percentage(of total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(size) / Double(total) * 100
    }

    private static let modifiedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

struct VolumeInfo: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let dataVolumeURL: URL?
    let purgeableCapacity: Int64
    let isRemovable: Bool
    let isNetworkVolume: Bool
    let isEjectable: Bool

    init(
        id: String,
        url: URL,
        name: String,
        totalCapacity: Int64,
        availableCapacity: Int64,
        dataVolumeURL: URL?,
        purgeableCapacity: Int64 = 0,
        isRemovable: Bool = false,
        isNetworkVolume: Bool = false,
        isEjectable: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.dataVolumeURL = dataVolumeURL
        self.purgeableCapacity = purgeableCapacity
        self.isRemovable = isRemovable
        self.isNetworkVolume = isNetworkVolume
        self.isEjectable = isEjectable
    }

    var usedCapacity: Int64 {
        totalCapacity - availableCapacity
    }

    var scanRoot: URL {
        if let dataVolumeURL { return dataVolumeURL }
        if url.path.hasPrefix("/Volumes/") { return url }
        return url
    }

    var volumeIcon: String {
        if isNetworkVolume { return "externaldrive.connected.to.line.below.fill" }
        if isRemovable || isEjectable { return "externaldrive.fill" }
        return "internaldrive.fill"
    }

    var formattedTotal: String { ByteFormatter.string(from: totalCapacity) }
    var formattedUsed: String { ByteFormatter.string(from: usedCapacity) }
    var formattedAvailable: String { ByteFormatter.string(from: availableCapacity) }
    var formattedPurgeable: String { ByteFormatter.string(from: purgeableCapacity) }
}
