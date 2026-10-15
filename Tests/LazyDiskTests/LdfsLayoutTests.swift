import Foundation
import LazyDiskFS
import XCTest

final class LdfsLayoutTests: XCTestCase {
    func testChildEntryStrideMatchesC() {
        // const char**, size_t, const char* on arm64/macOS
        XCTAssertEqual(MemoryLayout<ldfs_child_entry>.size, 24)
        XCTAssertEqual(MemoryLayout<ldfs_child_entry>.stride, 24)
    }

    func testTreeOptionsLayoutMatchesC() {
        XCTAssertEqual(MemoryLayout<ldfs_tree_options>.size, 96)
        XCTAssertEqual(MemoryLayout<ldfs_scan_options>.size, 88)
    }

    func testTreeOptionsInitializerRoundTrip() {
        "/tmp".withCString { cstr in
            var options = ldfs_tree_options(
                root_path: cstr,
                max_depth: 5,
                skip_hidden: true,
                firm_links: true,
                use_physical_size: true,
                worker_count: 3,
                buffer_size: 0x4000,
                turbo: false,
                children: nil,
                child_count: 0,
                should_cancel: nil,
                cancel_ctx: nil,
                on_restricted_path: nil,
                restricted_ctx: nil,
                metrics_out: nil
            )
            XCTAssertEqual(options.max_depth, 5)
            XCTAssertEqual(options.worker_count, 3)
            XCTAssertEqual(options.buffer_size, 0x4000)
            XCTAssertEqual(options.skip_hidden, true)
            XCTAssertEqual(options.firm_links, true)
            XCTAssertEqual(options.turbo, false)
        }
    }

}
