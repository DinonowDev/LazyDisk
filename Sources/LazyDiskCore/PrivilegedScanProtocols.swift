import Foundation

@objc(PrivilegedScanHelperProtocol)
public protocol PrivilegedScanHelperProtocol {
    func helperVersion(withReply reply: @escaping (NSString) -> Void)

    func startScanRequest(
        withID requestID: String,
        path: String,
        pathLength: UInt,
        firmLinks: Bool,
        maxConcurrentTaskCount: Int32,
        supportsPhysicalSize: Bool,
        useAbsoluteProgress: Bool,
        relProgressFactor: Double,
        withReply reply: @escaping (NSNumber?, NSError?) -> Void
    )

    func stopScanRequest(withID requestID: String)

    func getProgressOfScanRequests(
        withIDs requestIDs: [String],
        reply: @escaping ([String: Any], NSError?) -> Void
    )

    func getCloneCount(atPath path: String, withReply reply: @escaping (NSNumber, NSError?) -> Void)

    func getHardLinkCount(atPath path: String, withReply reply: @escaping (NSNumber, NSError?) -> Void)

    /// Legacy sizing entry point (kept for older clients).
    func scanTotalSize(atPath path: String, withReply reply: @escaping (NSNumber?, NSError?) -> Void)
}

public enum PrivilegedScanMachService {
    public static let name = "com.lazydisk.app.AdminHelper"
    public static let bundleIdentifier = "com.lazydisk.app.AdminHelper"
}

public struct PrivilegedScanProgress: Sendable {
    public let requestID: String
    public let filesScanned: Int64
    public let totalSize: Int64
    public let finished: Bool

    public init(requestID: String, filesScanned: Int64, totalSize: Int64, finished: Bool) {
        self.requestID = requestID
        self.filesScanned = filesScanned
        self.totalSize = totalSize
        self.finished = finished
    }
}

public struct PrivilegedScanConfiguration: Sendable {
    public var firmLinks: Bool
    public var maxConcurrentTaskCount: Int
    public var supportsPhysicalSize: Bool
    public var useAbsoluteProgress: Bool
    public var relProgressFactor: Double

    public init(
        firmLinks: Bool = true,
        maxConcurrentTaskCount: Int = NativeScanRuntime.daisyDefaultWorkers,
        supportsPhysicalSize: Bool = true,
        useAbsoluteProgress: Bool = false,
        relProgressFactor: Double = 1.0
    ) {
        self.firmLinks = firmLinks
        self.maxConcurrentTaskCount = maxConcurrentTaskCount
        self.supportsPhysicalSize = supportsPhysicalSize
        self.useAbsoluteProgress = useAbsoluteProgress
        self.relProgressFactor = relProgressFactor
    }
}

public struct PrivilegedScanResult: Sendable {
    public let totalSize: Int64
    public let filesScanned: Int64
    public let cloneDuplicateFiles: Int64
    public let scanMetrics: NativeScanMetrics?

    public init(
        totalSize: Int64,
        filesScanned: Int64,
        cloneDuplicateFiles: Int64 = 0,
        scanMetrics: NativeScanMetrics? = nil
    ) {
        self.totalSize = totalSize
        self.filesScanned = filesScanned
        self.cloneDuplicateFiles = cloneDuplicateFiles
        self.scanMetrics = scanMetrics
    }
}
