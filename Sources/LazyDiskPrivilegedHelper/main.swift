import AppKit
import Foundation
import LazyDiskCore
import Security

private enum HelperClientAuth {
    static let requirementString =
        "anchor apple generic and identifier \"com.lazydisk.app\"" as CFString

    static func accepts(connection: NSXPCConnection) -> Bool {
        let pid = connection.processIdentifier
        guard pid > 0 else { return false }
        let attributes: [String: Any] = [
            kSecGuestAttributePid as String: pid
        ]
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(
            nil,
            attributes as CFDictionary,
            [],
            &code
        ) == errSecSuccess, let code else {
            return false
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(requirementString, [], &requirement) == errSecSuccess,
              let requirement else {
            return false
        }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }
}

final class PrivilegedScanHelper: NSObject, NSXPCListenerDelegate, PrivilegedScanHelperProtocol {
    private let sessions = AdminScanSessionStore.shared

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard HelperClientAuth.accepts(connection: connection) else {
            return false
        }
        connection.exportedInterface = NSXPCInterface(with: PrivilegedScanHelperProtocol.self)
        connection.exportedObject = self
        connection.activate()
        return true
    }

    func helperVersion(withReply reply: @escaping (NSString) -> Void) {
        reply("3" as NSString)
    }

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
    ) {
        let scanPath = path
        Task {
            let config = PrivilegedScanConfiguration(
                firmLinks: firmLinks,
                maxConcurrentTaskCount: Int(maxConcurrentTaskCount),
                supportsPhysicalSize: supportsPhysicalSize,
                useAbsoluteProgress: useAbsoluteProgress,
                relProgressFactor: relProgressFactor
            )
            await sessions.launch(requestID: requestID, path: scanPath, configuration: config)
            reply(1, nil)
        }
    }

    func stopScanRequest(withID requestID: String) {
        Task { await sessions.stop(requestID: requestID) }
    }

    func getProgressOfScanRequests(
        withIDs requestIDs: [String],
        reply: @escaping ([String: Any], NSError?) -> Void
    ) {
        Task {
            let progress = await sessions.progress(for: requestIDs)
            let payload = Dictionary(uniqueKeysWithValues: progress.map { item in
                (
                    item.requestID,
                    [
                        "filesScanned": NSNumber(value: item.filesScanned),
                        "totalSize": NSNumber(value: item.totalSize),
                        "finished": item.finished
                    ] as [String: Any]
                )
            })
            reply(payload, nil)
        }
    }

    func getCloneCount(atPath path: String, withReply reply: @escaping (NSNumber, NSError?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            if let result = try? PrivilegedScanRunner.performScan(atPath: path) {
                let groups = result.scanMetrics?.cloneGroupsMerged ?? Int32(result.cloneDuplicateFiles)
                reply(NSNumber(value: groups), nil)
            } else {
                reply(0, nil)
            }
        }
    }

    func getHardLinkCount(atPath path: String, withReply reply: @escaping (NSNumber, NSError?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            if let result = try? PrivilegedScanRunner.performScan(atPath: path) {
                let skipped = result.scanMetrics?.hardlinkFilesSkipped ?? 0
                reply(NSNumber(value: skipped), nil)
            } else {
                reply(0, nil)
            }
        }
    }

    func scanTotalSize(atPath path: String, withReply reply: @escaping (NSNumber?, NSError?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard FileManager.default.fileExists(atPath: path) else {
                reply(nil, NSError(domain: "LazyDisk.AdminHelper", code: Int(ENOENT), userInfo: [
                    NSLocalizedDescriptionKey: "Path does not exist."
                ]))
                return
            }
            if let total = PrivilegedScanRunner.scanTotalSize(atPath: path) {
                reply(NSNumber(value: total), nil)
            } else {
                reply(nil, NSError(domain: "LazyDisk.AdminHelper", code: Int(EIO), userInfo: [
                    NSLocalizedDescriptionKey: "Native scan failed."
                ]))
            }
        }
    }

    func deleteLocalSnapshot(
        named name: String,
        atPath path: String,
        withReply reply: @escaping (NSNumber?, NSError?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try APFSSnapshotStore.delete(name: name, volumePath: path)
                reply(NSNumber(value: 1), nil)
            } catch {
                let nsError = error as NSError
                reply(nil, nsError)
            }
        }
    }
}

let delegate = PrivilegedScanHelper()
let listener = NSXPCListener(machServiceName: PrivilegedScanMachService.name)
listener.delegate = delegate
listener.resume()
dispatchMain()
