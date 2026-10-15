// DiskBrowserViewModel+Permissions.swift — Privacy permission checks and requests.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Permissions

    var privacyGatePermissions: [PermissionItem] {
        permissions.filter { $0.kind.isPrivacyGate }
    }

    var requiredPermissions: [PermissionItem] {
        permissions.filter { $0.kind != .adminHelper }
    }

    var requiredPermissionsCount: Int {
        requiredPermissions.count
    }

    var requiredPermissionsGrantedCount: Int {
        requiredPermissions.filter(\.isGranted).count
    }

    func displaysPermissionAsGranted(_ permission: PermissionItem) -> Bool {
        if permission.isGranted { return true }
        if permission.kind == .adminHelper, hasFullDiskAccessPermission { return true }
        return false
    }

    private var hasFullDiskAccessPermission: Bool {
        permissions.first(where: { $0.kind == .fullDiskAccess })?.isGranted == true
    }

    func refreshPermissions() {
        permissions = PermissionsService.checkAll()
    }

    func requestAllPermissions() {
        guard !allPermissionsGranted else {
            PermissionsService.openPrivacySettings()
            return
        }
        PermissionsService.requestAll()
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            refreshPermissions()
        }
    }

    func showPermissions() {
        refreshPermissions()
        appPhase = .permissions
    }

}
