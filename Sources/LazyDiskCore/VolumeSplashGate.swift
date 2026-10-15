import Foundation

/// One-shot gate for Daisy-style splash readiness during a volume tree walk.
public actor VolumeSplashGate {
    private var signaled = false
    private var readyElapsedSeconds: Double?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init() {}

    public func signal(elapsed: Double? = nil) {
        guard !signaled else { return }
        signaled = true
        if let elapsed {
            readyElapsedSeconds = elapsed
        }
        let pending = waiters
        waiters = []
        for waiter in pending {
            waiter.resume()
        }
    }

    public func elapsedSeconds() -> Double? {
        readyElapsedSeconds
    }

    public func wait() async {
        if signaled { return }
        await withCheckedContinuation { continuation in
            if signaled {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }
}
