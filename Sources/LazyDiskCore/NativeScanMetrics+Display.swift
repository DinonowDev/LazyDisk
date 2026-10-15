import Foundation

extension NativeScanMetrics {
    public var hasVisibleValues: Bool {
        cloneBytesMerged > 0 || cloneGroupsMerged > 0 || hardlinkFilesSkipped > 0
    }
}
