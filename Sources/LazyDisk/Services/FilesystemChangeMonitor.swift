import CoreServices
import Foundation

/// Watches filesystem changes via macOS FSEvents — no polling or full scans required.
final class FilesystemChangeMonitor: @unchecked Sendable {
    typealias ChangeHandler = @Sendable ([String]) -> Void

    private var stream: FSEventStreamRef?
    private var handler: ChangeHandler?
    private let queue = DispatchQueue(label: "com.lazydisk.fsevents", qos: .utility)

    func start(watchPaths: [String], latency: CFTimeInterval = 0.3, handler: @escaping ChangeHandler) {
        stop()
        guard !watchPaths.isEmpty else { return }

        self.handler = handler

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            watchPaths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        handler = nil
    }

    fileprivate func deliver(paths: [String]) {
        handler?(paths)
    }

    deinit {
        stop()
    }
}

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<FilesystemChangeMonitor>.fromOpaque(info).takeUnretainedValue()

    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
    monitor.deliver(paths: paths)
}
