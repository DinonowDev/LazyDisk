import Foundation

extension DiskItem {
    private enum CodingKeys: String, CodingKey {
        case id, url, name, size, isDirectory, children, isScanning, isHidden, isVirtual
        case modifiedDate, fileKind, isCloudPlaceholder, isPurgeable
        case linkCount, cloneReferenceCount, role, sizeIsEstimate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        size = try container.decode(Int64.self, forKey: .size)
        isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        children = try container.decodeIfPresent([DiskItem].self, forKey: .children) ?? []
        isScanning = try container.decodeIfPresent(Bool.self, forKey: .isScanning) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        isVirtual = try container.decodeIfPresent(Bool.self, forKey: .isVirtual) ?? false
        modifiedDate = try container.decodeIfPresent(Date.self, forKey: .modifiedDate)
        fileKind = try container.decodeIfPresent(FileKind.self, forKey: .fileKind)
            ?? FileKind.detect(url: url, isDirectory: isDirectory)
        isCloudPlaceholder = try container.decodeIfPresent(Bool.self, forKey: .isCloudPlaceholder) ?? false
        isPurgeable = try container.decodeIfPresent(Bool.self, forKey: .isPurgeable) ?? false
        linkCount = try container.decodeIfPresent(Int.self, forKey: .linkCount) ?? 1
        cloneReferenceCount = try container.decodeIfPresent(UInt32.self, forKey: .cloneReferenceCount) ?? 0
        role = try container.decodeIfPresent(DiskItemRole.self, forKey: .role) ?? .regular
        sizeIsEstimate = try container.decodeIfPresent(Bool.self, forKey: .sizeIsEstimate) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(name, forKey: .name)
        try container.encode(size, forKey: .size)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(children, forKey: .children)
        try container.encode(isScanning, forKey: .isScanning)
        try container.encode(isHidden, forKey: .isHidden)
        try container.encode(isVirtual, forKey: .isVirtual)
        try container.encodeIfPresent(modifiedDate, forKey: .modifiedDate)
        try container.encode(fileKind, forKey: .fileKind)
        try container.encode(isCloudPlaceholder, forKey: .isCloudPlaceholder)
        try container.encode(isPurgeable, forKey: .isPurgeable)
        try container.encode(linkCount, forKey: .linkCount)
        try container.encode(cloneReferenceCount, forKey: .cloneReferenceCount)
        try container.encode(role, forKey: .role)
        try container.encode(sizeIsEstimate, forKey: .sizeIsEstimate)
    }
}
