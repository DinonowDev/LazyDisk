import AppKit
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [Color.accentColor.opacity(0.12), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 200
                )

                VStack(spacing: 16) {
                    appIcon
                    Text(AppInfo.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(L10n.aboutTagline)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
            }

            VStack(spacing: 10) {
                infoRow(label: L10n.aboutVersion, value: AppInfo.versionString)
                infoRow(label: L10n.aboutDeveloper, value: AppInfo.developer)
                infoRow(label: L10n.aboutCopyright, value: "© \(AppInfo.copyrightYear) \(AppInfo.developer)")
                infoRow(label: L10n.aboutLicense, value: "MIT")
            }
            .padding(.horizontal, 32)

            Button {
                if let url = URL(string: AppInfo.githubURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label(L10n.aboutGitHub, systemImage: "link")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.link)
            .padding(.top, 16)

            Spacer(minLength: 20)

            HStack {
                Spacer()
                Button(L10n.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 380, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 6)

            Image(systemName: "externaldrive.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .textSelection(.enabled)
        }
    }
}
