import XCTest
import LazyDiskCore

final class VolumeFilterTests: XCTestCase {
    func testHidesAPFSSystemVolumes() {
        let systemPaths = [
            "/System/Volumes/Hardware",
            "/System/Volumes/Preboot",
            "/System/Volumes/Update",
            "/System/Volumes/VM",
            "/System/Volumes/iSCPreboot",
            "/System/Volumes/xarts",
            "/System/Volumes/Data/home",
        ]

        for path in systemPaths {
            XCTAssertFalse(
                VolumeFilter.isUserFacing(path: path, isBrowsable: nil),
                "Expected \(path) to be hidden"
            )
        }
    }

    func testShowsUserFacingVolumes() {
        XCTAssertTrue(VolumeFilter.isUserFacing(path: "/", isBrowsable: true))
        XCTAssertTrue(VolumeFilter.isUserFacing(path: "/Volumes/My Drive", isBrowsable: true))
        XCTAssertTrue(VolumeFilter.isUserFacing(path: "/Volumes/USB", isBrowsable: nil))
    }

    func testHidesNonBrowsableVolumes() {
        XCTAssertFalse(VolumeFilter.isUserFacing(path: "/some/other/mount", isBrowsable: false))
    }
}
