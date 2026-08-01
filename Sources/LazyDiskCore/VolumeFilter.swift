import Foundation

public enum VolumeFilter {
    /// Whether a mounted volume should appear in the user-facing volume picker.
    public static func isUserFacing(path: String, isBrowsable: Bool?) -> Bool {
        if path == "/dev" || path.hasPrefix("/dev/") { return false }

        // External and network drives mounted under /Volumes.
        if path.hasPrefix("/Volumes/") { return true }

        // Boot volume; scan root resolves to /System/Volumes/Data when present.
        if path == "/" { return true }

        // APFS system roles: Hardware, Preboot, VM, Update, iSCPreboot, xART, etc.
        if path.hasPrefix("/System/Volumes/") { return false }

        if isBrowsable == false { return false }

        return true
    }
}
