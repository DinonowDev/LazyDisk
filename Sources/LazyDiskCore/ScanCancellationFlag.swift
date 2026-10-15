import Foundation

/// Thread-safe cancel flag for native scan workers (pthread / ldfs); not tied to Swift `Task`.
public final class ScanCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    public func shouldCancelHandler() -> @Sendable () -> Bool {
        { [self] in self.isCancelled }
    }

    public static let taskCancellationFallback: @Sendable () -> Bool = { Task.isCancelled }
}
