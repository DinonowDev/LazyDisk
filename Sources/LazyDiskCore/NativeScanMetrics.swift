import Foundation

public struct NativeScanMetrics: Sendable, Equatable {
    public let cloneBytesMerged: Int64
    public let cloneGroupsMerged: Int32
    public let hardlinkFilesSkipped: Int64

    public init(cloneBytesMerged: Int64, cloneGroupsMerged: Int32, hardlinkFilesSkipped: Int64) {
        self.cloneBytesMerged = cloneBytesMerged
        self.cloneGroupsMerged = cloneGroupsMerged
        self.hardlinkFilesSkipped = hardlinkFilesSkipped
    }
}
