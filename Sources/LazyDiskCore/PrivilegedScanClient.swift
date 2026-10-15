import Foundation

public final class PrivilegedScanClient: @unchecked Sendable {
    public static let shared = PrivilegedScanClient()

    private init() {}

    public func isHelperReachable() -> Bool {
        guard PrivilegedHelperInstaller.isHelperJobRegistered() else { return false }
        guard let (connection, proxy) = makeConnection() else { return false }
        defer { connection.invalidate() }

        let gate = ReachabilityGate()
        proxy.helperVersion { version in
            gate.complete(success: (version as String).isEmpty == false)
        }
        return gate.wait(seconds: 2)
    }

    public func startScanRequest(
        path: String,
        configuration: PrivilegedScanConfiguration = PrivilegedScanConfiguration(),
        requestID: String = UUID().uuidString
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            guard let (connection, proxy) = makeConnection(
                onInterrupt: { continuation.resume(throwing: PrivilegedScanClientError.connectionInterrupted) }
            ) else {
                continuation.resume(throwing: PrivilegedScanClientError.unavailable)
                return
            }
            proxy.startScanRequest(
                withID: requestID,
                path: path,
                pathLength: 0,
                firmLinks: configuration.firmLinks,
                maxConcurrentTaskCount: Int32(configuration.maxConcurrentTaskCount),
                supportsPhysicalSize: configuration.supportsPhysicalSize,
                useAbsoluteProgress: configuration.useAbsoluteProgress,
                relProgressFactor: configuration.relProgressFactor
            ) { accepted, error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard accepted != nil else {
                    continuation.resume(throwing: PrivilegedScanClientError.emptyResult)
                    return
                }
                continuation.resume()
            }
        }
    }

    public func scanProgress(requestIDs: [String]) async throws -> [PrivilegedScanProgress] {
        try await withCheckedThrowingContinuation { continuation in
            guard let (connection, proxy) = makeConnection(
                onInterrupt: { continuation.resume(throwing: PrivilegedScanClientError.connectionInterrupted) }
            ) else {
                continuation.resume(throwing: PrivilegedScanClientError.unavailable)
                return
            }
            proxy.getProgressOfScanRequests(withIDs: requestIDs) { payload, error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let mapped = requestIDs.compactMap { id -> PrivilegedScanProgress? in
                    guard let dict = payload[id] as? [String: Any] else { return nil }
                    return PrivilegedScanProgress(
                        requestID: id,
                        filesScanned: Self.int64(from: dict["filesScanned"]),
                        totalSize: Self.int64(from: dict["totalSize"]),
                        finished: dict["finished"] as? Bool ?? false
                    )
                }
                continuation.resume(returning: mapped)
            }
        }
    }

    public func stopScanRequest(requestID: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let (connection, proxy) = makeConnection(onInterrupt: { continuation.resume() }) else {
                continuation.resume()
                return
            }
            proxy.stopScanRequest(withID: requestID)
            connection.invalidate()
            continuation.resume()
        }
    }

    /// Starts helper scan, polls `getProgressOfScanRequests` until finished (Daisy-style live progress).
    public func scanPathWithLiveProgress(
        atPath path: String,
        configuration: PrivilegedScanConfiguration = PrivilegedScanConfiguration(),
        pollIntervalNanoseconds: UInt64 = 150_000_000,
        onProgress: @escaping @Sendable (PrivilegedScanProgress) -> Void
    ) async throws -> Int64 {
        let requestID = UUID().uuidString
        try await startScanRequest(path: path, configuration: configuration, requestID: requestID)
        defer { Task { await stopScanRequest(requestID: requestID) } }

        do {
            while true {
                try Task.checkCancellation()
                let items = try await scanProgress(requestIDs: [requestID])
                guard let item = items.first else {
                    throw PrivilegedScanClientError.emptyResult
                }
                onProgress(item)
                if item.finished {
                    return item.totalSize
                }
                try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
            }
        } catch is CancellationError {
            await stopScanRequest(requestID: requestID)
            throw CancellationError()
        }
    }

    public func scanTotalSize(atPath path: String) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            guard let (connection, proxy) = makeConnection(
                onInterrupt: { continuation.resume(throwing: PrivilegedScanClientError.connectionInterrupted) }
            ) else {
                continuation.resume(throwing: PrivilegedScanClientError.unavailable)
                return
            }
            proxy.scanTotalSize(atPath: path) { number, nsError in
                connection.invalidate()
                if let nsError {
                    continuation.resume(throwing: nsError)
                    return
                }
                guard let number else {
                    continuation.resume(throwing: PrivilegedScanClientError.emptyResult)
                    return
                }
                continuation.resume(returning: number.int64Value)
            }
        }
    }

    public func cloneCount(atPath path: String) async throws -> Int64 {
        try await withCheckedThrowingContinuation { continuation in
            guard let (connection, proxy) = makeConnection(
                onInterrupt: { continuation.resume(throwing: PrivilegedScanClientError.connectionInterrupted) }
            ) else {
                continuation.resume(throwing: PrivilegedScanClientError.unavailable)
                return
            }
            proxy.getCloneCount(atPath: path) { number, error in
                connection.invalidate()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: number.int64Value)
            }
        }
    }

    private static func int64(from value: Any?) -> Int64 {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let direct = value as? Int64 {
            return direct
        }
        return 0
    }

    private func makeConnection(
        onInterrupt: @escaping () -> Void = {}
    ) -> (NSXPCConnection, PrivilegedScanHelperProtocol)? {
        let connection = NSXPCConnection(
            machServiceName: PrivilegedScanMachService.name,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: PrivilegedScanHelperProtocol.self)
        connection.invalidationHandler = onInterrupt
        connection.interruptionHandler = onInterrupt
        connection.activate()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            onInterrupt()
            connection.invalidate()
        }) as? PrivilegedScanHelperProtocol else {
            connection.invalidate()
            return nil
        }
        return (connection, proxy)
    }
}

private final class ReachabilityGate: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    private var success = false

    func complete(success: Bool) {
        lock.lock()
        self.success = success
        done = true
        lock.unlock()
    }

    func wait(seconds: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            lock.lock()
            let finished = done
            let ok = success
            lock.unlock()
            if finished { return ok }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}

public enum PrivilegedScanClientError: LocalizedError {
    case unavailable
    case emptyResult
    case connectionInvalidated
    case connectionInterrupted

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Admin helper is not installed or not reachable."
        case .emptyResult:
            return "Admin helper returned no size."
        case .connectionInvalidated:
            return "Connection to admin helper was invalidated."
        case .connectionInterrupted:
            return "Connection to admin helper was interrupted."
        }
    }
}
