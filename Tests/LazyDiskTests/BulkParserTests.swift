import Darwin
import LazyDiskFS
import XCTest

final class BulkParserTests: XCTestCase {
    func testParseSyntheticExtendedBulkRecord() {
        var seed = ldfs_bulk_entry()
        seed.error = 0
        withUnsafeMutablePointer(to: &seed.name) { namePtr in
            namePtr.withMemoryRebound(to: CChar.self, capacity: 256) { cString in
                strcpy(cString, "clone.bin")
            }
        }
        seed.obj_type = fsobj_type_t(1) // VREG
        seed.file_id = 42
        seed.flags = 0
        seed.dev = 0x0102_0304
        seed.data_length = 1000
        seed.alloc_size = 4096
        seed.fsid.val.0 = 0xAAA
        seed.fsid.val.1 = 0xBBB
        seed.clone_id = 0xDEAD_BEEF
        seed.clone_refcnt = 3
        seed.has_fsid = 1

        var returned = attribute_set_t()
        let capacity = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        let written = ldfs_bulk_pack_synthetic_entry(buffer, capacity, &seed, &returned)
        XCTAssertGreaterThan(written, MemoryLayout<attribute_set_t>.size)

        var parsed = ldfs_bulk_entry()
        var cursor = buffer.advanced(by: MemoryLayout<attribute_set_t>.size)
        let bufferEnd = UnsafeMutableRawPointer(buffer)
            .advanced(by: capacity)
            .assumingMemoryBound(to: CChar.self)
        let status = cursor.withMemoryRebound(to: CChar.self, capacity: capacity) { charBase in
            var cursorPtr: UnsafeMutablePointer<CChar>? = charBase
            return ldfs_bulk_parse_entry(&cursorPtr, bufferEnd, &returned, &parsed)
        }
        XCTAssertEqual(status, 0)
        XCTAssertEqual(parsed.error, 0)
        parsedName(parsed) { XCTAssertEqual($0, "clone.bin") }
        XCTAssertEqual(parsed.obj_type, seed.obj_type)
        XCTAssertEqual(parsed.file_id, 42)
        XCTAssertEqual(parsed.dev, 0x0102_0304)
        XCTAssertEqual(parsed.data_length, 1000)
        XCTAssertEqual(parsed.alloc_size, 4096)
        XCTAssertEqual(parsed.clone_id, 0xDEAD_BEEF)
        XCTAssertEqual(parsed.clone_refcnt, 3)
        XCTAssertEqual(parsed.has_fsid, 1)
        XCTAssertEqual(parsed.fsid.val.0, 0xAAA)
        XCTAssertEqual(parsed.fsid.val.1, 0xBBB)
    }

    func testParseSkipsIntermediateCMNEXTFields() {
        var returned = attribute_set_t()
        returned.forkattr = UInt32(ATTR_CMNEXT_EXT_FLAGS | ATTR_CMNEXT_RECURSIVE_GENCOUNT)

        let capacity = 256
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        var offset = 0
        memcpy(buffer.advanced(by: offset), &returned, MemoryLayout<attribute_set_t>.size)
        offset += MemoryLayout<attribute_set_t>.size

        var extFlags: UInt64 = 0xA5
        var genCount: UInt64 = 0xB6
        memcpy(buffer.advanced(by: offset), &extFlags, 8)
        offset += 8
        memcpy(buffer.advanced(by: offset), &genCount, 8)
        offset += 8

        var parsed = ldfs_bulk_entry()
        var cursor = buffer.advanced(by: MemoryLayout<attribute_set_t>.size)
        let bufferEnd = UnsafeMutableRawPointer(buffer)
            .advanced(by: capacity)
            .assumingMemoryBound(to: CChar.self)
        let status = cursor.withMemoryRebound(to: CChar.self, capacity: capacity) { charBase in
            var cursorPtr: UnsafeMutablePointer<CChar>? = charBase
            return ldfs_bulk_parse_entry(&cursorPtr, bufferEnd, &returned, &parsed)
        }
        XCTAssertEqual(status, 0)
        XCTAssertEqual(parsed.clone_id, 0)
    }

    private func parsedName(_ entry: ldfs_bulk_entry, assert: (String) -> Void) {
        withUnsafePointer(to: entry.name) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 256) {
                assert(String(cString: $0))
            }
        }
    }
}
