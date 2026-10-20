import Foundation

public struct DiskItem: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let url: URL
    public let name: String
    public var size: Int64
    public let isDirectory: Bool
    public var children: [DiskItem]
    public var isScanning: Bool
    public let isHidden: Bool
    public let isVirtual: Bool
    public var modifiedDate: Date?
    public var fileKind: FileKind
    public var isCloudPlaceholder: Bool
    public var isPurgeable: Bool
    public var linkCount: Int
    public var cloneReferenceCount: UInt32
    public var role: DiskItemRole
    public var sizeIsEstimate: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        size: Int64 = 0,
        isDirectory: Bool = false,
        children: [DiskItem] = [],
        isScanning: Bool = false,
        isHidden: Bool = false,
        isVirtual: Bool = false,
        modifiedDate: Date? = nil,
        fileKind: FileKind? = nil,
        isCloudPlaceholder: Bool = false,
        isPurgeable: Bool = false,
        linkCount: Int = 1,
        cloneReferenceCount: UInt32 = 0,
        role: DiskItemRole = .regular,
        sizeIsEstimate: Bool = false
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.isScanning = isScanning
        self.isHidden = isHidden
        self.isVirtual = isVirtual
        self.modifiedDate = modifiedDate
        self.fileKind = fileKind ?? FileKind.detect(url: url, isDirectory: isDirectory)
        self.isCloudPlaceholder = isCloudPlaceholder
        self.isPurgeable = isPurgeable
        self.linkCount = linkCount
        self.cloneReferenceCount = cloneReferenceCount
        self.role = role
        self.sizeIsEstimate = sizeIsEstimate
    }

    /// Bytes deleting this item actually returns to the volume.
    public var reclaimableSize: Int64 {
        switch role {
        case .purgeable, .unscanned, .cloudSummary:
            return 0
        case .snapshot, .snapshotGroup:
            return max(0, size)
        case .regular:
            if isCloudPlaceholder { return 0 }
            if !isDirectory, linkCount > 1 { return 0 }
            if !isDirectory, cloneReferenceCount > 1 { return 0 }
            return max(0, size)
        }
    }

    public var formattedSize: String {
        ByteFormatter.string(from: size)
    }
}
