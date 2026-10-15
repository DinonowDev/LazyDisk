import Foundation

public enum AdminScanSessionError: Error {
    case unknownRequestID
    case scanFailed(Error)
}

public actor AdminScanSessionStore {
    public static let shared = AdminScanSessionStore()

    private struct RunningScan {
        let task: Task<PrivilegedScanResult, Error>
        let cancelFlag: ScanCancellationFlag
        var filesScanned: Int64
        var totalSize: Int64
        var finished: Bool
        var storedResult: PrivilegedScanResult?
        var storedError: Error?
    }

    private var scans: [String: RunningScan] = [:]

    /// Starts a scan in the background; returns immediately (Daisy-style async request).
    public func launch(
        requestID: String,
        path: String,
        configuration: PrivilegedScanConfiguration = PrivilegedScanConfiguration()
    ) {
        if let existing = scans[requestID], !existing.finished {
            return
        }

        let cancelFlag = ScanCancellationFlag()
        let shouldCancel = cancelFlag.shouldCancelHandler()
        let task = Task.detached(priority: .utility) {
            try PrivilegedScanRunner.performScan(
                atPath: path,
                configuration: configuration,
                progress: { update in
                    Task {
                        await AdminScanSessionStore.shared.reportProgress(
                            requestID: requestID,
                            filesScanned: update.filesScanned,
                            totalSize: update.totalSize
                        )
                    }
                },
                shouldCancel: shouldCancel
            )
        }

        scans[requestID] = RunningScan(
            task: task,
            cancelFlag: cancelFlag,
            filesScanned: 0,
            totalSize: 0,
            finished: false,
            storedResult: nil,
            storedError: nil
        )

        Task {
            await finalizeTask(requestID: requestID, task: task)
        }
    }

    /// Blocks until the scan completes (used when caller wants the final result).
    public func waitForResult(
        requestID: String,
        path: String,
        configuration: PrivilegedScanConfiguration = PrivilegedScanConfiguration()
    ) async throws -> PrivilegedScanResult {
        if scans[requestID] == nil {
            launch(requestID: requestID, path: path, configuration: configuration)
        }
        guard let scan = scans[requestID] else {
            throw AdminScanSessionError.unknownRequestID
        }
        if let result = scan.storedResult {
            return result
        }
        if let error = scan.storedError {
            throw AdminScanSessionError.scanFailed(error)
        }
        do {
            let result = try await scan.task.value
            return result
        } catch {
            throw AdminScanSessionError.scanFailed(error)
        }
    }

    public func reportProgress(requestID: String, filesScanned: Int64, totalSize: Int64) {
        guard var scan = scans[requestID], !scan.finished else { return }
        scan.filesScanned = max(scan.filesScanned, filesScanned)
        scan.totalSize = max(scan.totalSize, totalSize)
        scans[requestID] = scan
    }

    private func finalizeTask(requestID: String, task: Task<PrivilegedScanResult, Error>) async {
        do {
            let result = try await task.value
            guard var scan = scans[requestID] else { return }
            scan.filesScanned = result.filesScanned
            scan.totalSize = result.totalSize
            scan.finished = true
            scan.storedResult = result
            scans[requestID] = scan
        } catch {
            guard var scan = scans[requestID] else { return }
            scan.finished = true
            scan.storedError = error
            scans[requestID] = scan
        }
    }

    public func stop(requestID: String) {
        if let scan = scans[requestID] {
            scan.cancelFlag.cancel()
            scan.task.cancel()
        }
        scans.removeValue(forKey: requestID)
    }

    public func progress(for requestIDs: [String]) -> [PrivilegedScanProgress] {
        requestIDs.compactMap { id in
            guard let scan = scans[id] else { return nil }
            return PrivilegedScanProgress(
                requestID: id,
                filesScanned: scan.filesScanned,
                totalSize: scan.totalSize,
                finished: scan.finished
            )
        }
    }

    public func resultIfFinished(requestID: String) -> PrivilegedScanResult? {
        scans[requestID]?.storedResult
    }
}
