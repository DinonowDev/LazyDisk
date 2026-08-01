// DiskBrowserViewModel+Permissions.swift — Privacy permission checks and requests.
import AppKit
import Foundation
import SwiftUI

extension DiskBrowserViewModel {
    // MARK: - Permissions

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
