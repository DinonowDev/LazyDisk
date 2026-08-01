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
        isPurgeable: Bool = false
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
    }

    public var formattedSize: String {
        ByteFormatter.string(from: size)
    }
}
