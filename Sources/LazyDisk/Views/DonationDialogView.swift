import AppKit
import SwiftUI

struct DonationDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNetwork: DonationNetwork = DonationNetwork.all[0]
    @State private var copiedNetworkID: String?
    @State private var heartPulse = false
    @State private var glowRotation: Double = 0

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                networkPicker
                    .padding(.horizontal, 24)

                addressCard
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                allNetworksList
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                footer
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 520)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                heartPulse = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                glowRotation = 360
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            AngularGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.pink.opacity(0.12),
                    Color.purple.opacity(0.14),
                    Color.orange.opacity(0.1),
                    Color.accentColor.opacity(0.18),
                ],
                center: .center,
                angle: .degrees(glowRotation)
            )
            .blur(radius: 60)
            .opacity(0.9)

            RadialGradient(
                colors: [selectedNetwork.accent.opacity(0.12), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 320
            )
        }
        .animation(.easeInOut(duration: 0.45), value: selectedNetwork.id)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.pink.opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                    .scaleEffect(heartPulse ? 1.08 : 0.92)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink, Color.orange.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.pink.opacity(0.45), radius: 16, y: 6)

                Image(systemName: "heart.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(heartPulse ? 1.06 : 1.0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.donateTitle)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(L10n.donateSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.donateThankYou)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
    }

    private var networkPicker: some View {
        HStack(spacing: 8) {
            ForEach(DonationNetwork.all) { network in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        selectedNetwork = network
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: network.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(network.symbol)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedNetwork.id == network.id ? .white : network.accent)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                selectedNetwork.id == network.id
                                    ? LinearGradient(colors: network.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [network.accent.opacity(0.1), network.accent.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selectedNetwork.id == network.id ? Color.clear : network.accent.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(selectedNetwork.name, systemImage: selectedNetwork.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selectedNetwork.accent)

                Spacer()

                Text(selectedNetwork.symbol)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(selectedNetwork.accent.opacity(0.12)))
                    .foregroundStyle(selectedNetwork.accent)
            }

            Text(selectedNetwork.address)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

            Button {
                copyAddress(selectedNetwork)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copiedNetworkID == selectedNetwork.id ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    Text(copiedNetworkID == selectedNetwork.id ? L10n.donateCopied : L10n.donateCopy)
                        .font(.system(size: 13, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedNetwork.accent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: selectedNetwork.accent.opacity(0.15), radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [selectedNetwork.accent.opacity(0.35), selectedNetwork.accent.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedNetwork.id)
    }

    private var allNetworksList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.donateAllNetworks)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(DonationNetwork.all) { network in
                    HStack(spacing: 10) {
                        Image(systemName: network.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(network.accent)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(network.name)
                                .font(.system(size: 11, weight: .semibold))
                            Text(truncated(network.address))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            copyAddress(network)
                        } label: {
                            Image(systemName: copiedNetworkID == network.id ? "checkmark" : "square.on.square")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(copiedNetworkID == network.id ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(network.id == selectedNetwork.id ? network.accent.opacity(0.08) : Color.primary.opacity(0.03))
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            selectedNetwork = network
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(L10n.done) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private func truncated(_ address: String) -> String {
        guard address.count > 22 else { return address }
        return "\(address.prefix(10))…\(address.suffix(8))"
    }

    private func copyAddress(_ network: DonationNetwork) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(network.address, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copiedNetworkID = network.id
            selectedNetwork = network
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedNetworkID == network.id {
                withAnimation { copiedNetworkID = nil }
            }
        }
    }
}
