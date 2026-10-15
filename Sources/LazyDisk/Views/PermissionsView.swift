import AppKit
import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    private var allGranted: Bool { viewModel.allPermissionsGranted }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            RadialGradient(colors: [allGranted ? Color.green.opacity(0.06) : Color.accentColor.opacity(0.06), Color.clear], center: .top, startRadius: 0, endRadius: 500).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    header.padding(.bottom, 28)
                    permissionsList
                    if showFullDiskTargetHint { fullDiskTargetHint.padding(.top, 16) }
                    if showTerminalHint { terminalHint.padding(.top, 16) }
                    actionButtons.padding(.top, 28)
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 48)
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.refreshPermissionsDeferred() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshPermissionsDeferred()
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { viewModel.refreshPermissions() }
            }
        }
    }

    private var showTerminalHint: Bool {
        !PermissionsService.isRunningAsAppBundle && !allGranted
    }

    private var showFullDiskTargetHint: Bool {
        guard PermissionsService.isRunningAsAppBundle else { return false }
        guard let fullDisk = viewModel.permissions.first(where: { $0.kind == .fullDiskAccess }) else { return true }
        return !viewModel.displaysPermissionAsGranted(fullDisk)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: allGranted ? "checkmark.shield.fill" : "lock.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(allGranted ? .green : Color.accentColor)

            Text(allGranted ? L10n.permAllSet : L10n.permRequired)
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text(allGranted ? L10n.permAllSetDesc : L10n.permRequiredDesc)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var permissionsList: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.privacyGatePermissions) { permission in
                PermissionRow(
                    permission: permission,
                    displaysAsGranted: viewModel.displaysPermissionAsGranted(permission)
                )
            }

            HStack {
                Image(systemName: allGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(allGranted ? .green : .orange)
                Text(allGranted
                     ? L10n.permReadyScan
                     : L10n.permGrantedCount(viewModel.requiredPermissionsGrantedCount, viewModel.requiredPermissionsCount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(allGranted ? .green : .orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)).shadow(color: .black.opacity(0.06), radius: 16, y: 6))
    }

    private var fullDiskTargetHint: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.badge.questionmark").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.permFDATargetTitle).font(.system(size: 12, weight: .semibold))
                    Text(L10n.permFDATargetHint(PermissionsService.fullDiskAccessTargetPath))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(L10n.permRestartAfterFDA).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Button(L10n.permCopyAppPath) { PermissionsService.copyFullDiskAccessTargetToPasteboard() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(L10n.permCheckAgain) { viewModel.refreshPermissions() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.08)))
    }

    private var terminalHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.permTerminalTitle).font(.system(size: 12, weight: .semibold))
                Text(L10n.permTerminalHint).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.08)))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if allGranted {
                Button { viewModel.startInitialScan() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text(L10n.startScan).font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: 320)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.selectedVolume == nil)
                .keyboardShortcut(.defaultAction)

                HStack(spacing: 16) {
                    Button(L10n.back) { viewModel.appPhase = .welcome }.buttonStyle(.plain).foregroundStyle(.secondary)
                    Button(L10n.openSettings) { PermissionsService.openPrivacySettings() }.buttonStyle(.borderless).font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            } else {
                Button { viewModel.requestAllPermissions() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text(L10n.grantAllPerms).font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: 320)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 16) {
                    Button(L10n.back) { viewModel.appPhase = .welcome }.buttonStyle(.plain).foregroundStyle(.secondary)
                    Button(L10n.permCheckAgain) { viewModel.refreshPermissions() }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Button { viewModel.startInitialScan() } label: {
                        HStack(spacing: 6) {
                            Text(L10n.scanAnyway)
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.selectedVolume == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PermissionRow: View {
    let permission: PermissionItem
    var displaysAsGranted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(displaysAsGranted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: permission.icon).font(.system(size: 15)).foregroundStyle(displaysAsGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.system(size: 13, weight: .semibold))
                Text(permission.description).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: displaysAsGranted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(displaysAsGranted ? .green : .secondary.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(displaysAsGranted ? 0.03 : 0.06)))
    }
}
