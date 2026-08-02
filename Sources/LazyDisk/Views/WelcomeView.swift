import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                heroSection.padding(.bottom, 32)
                modeSelection.padding(.horizontal, 48).frame(maxWidth: 520)
                volumeCard.padding(.horizontal, 48).frame(maxWidth: 480).padding(.top, 24)
                actionButtons.padding(.top, 32).padding(.horizontal, 48)
                Spacer()
                footerHint.padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.accentColor.opacity(0.25), Color.clear], center: .center, startRadius: 0, endRadius: 60))
                    .frame(width: 120, height: 120)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 20, y: 8)
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            VStack(spacing: 8) {
                Text(L10n.welcomeTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(L10n.welcomeTagline)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.modeSelectTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                ForEach(InterfaceMode.allCases) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: viewModel.interfaceMode == mode
                    ) {
                        viewModel.setInterfaceMode(mode)
                    }
                }
            }
        }
    }

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.selectVolume)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker(L10n.volumeLabel, selection: volumeBinding) {
                ForEach(viewModel.volumes) { volume in
                    Text(volume.name).tag(Optional(volume))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let volume = viewModel.selectedVolume {
                VStack(spacing: 10) {
                    usageRow(label: L10n.totalCapacity, value: volume.formattedTotal)
                    usageRow(label: L10n.storageUsed, value: volume.formattedUsed, highlight: true)
                    usageRow(label: L10n.availableLabel, value: volume.formattedAvailable)

                    GeometryReader { geo in
                        let fraction = volume.totalCapacity > 0 ? CGFloat(volume.usedCapacity) / CGFloat(volume.totalCapacity) : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.08)).frame(height: 8)
                            Capsule()
                                .fill(fraction > 0.85 ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * fraction, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)).shadow(color: .black.opacity(0.06), radius: 16, y: 6))
    }

    private var actionButtons: some View {
        Button { viewModel.showPermissions() } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .semibold))
                Text(L10n.continueBtn).font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: 320)
            .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.selectedVolume == nil)
        .keyboardShortcut(.defaultAction)
    }

    private var footerHint: some View {
        VStack(spacing: 10) {
            Text(L10n.scanTakeTime).font(.system(size: 11)).foregroundStyle(.tertiary)

            HStack(spacing: 16) {
                Button {
                    viewModel.showPreferences = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text(L10n.preferences)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.showDonation = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.pink)
                        Text(L10n.donateSupport)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(colors: [Color.accentColor.opacity(0.06), Color.clear], center: .top, startRadius: 0, endRadius: 500)
        }
        .ignoresSafeArea()
    }

    private var volumeBinding: Binding<VolumeInfo?> {
        Binding(get: { viewModel.selectedVolume }, set: { viewModel.pickVolume($0) })
    }

    private func usageRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: highlight ? .bold : .medium, design: .monospaced)).foregroundStyle(highlight ? .primary : .secondary)
        }
    }
}

private struct ModeCard: View {
    let mode: InterfaceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: mode.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                Text(mode.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(mode.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(+2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.15) : .black.opacity(0.04), radius: 8, y: 3)
            }
        }
        .buttonStyle(.plain)
    }
}
