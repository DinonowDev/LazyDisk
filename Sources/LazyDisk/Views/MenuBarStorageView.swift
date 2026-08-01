import SwiftUI

struct MenuBarStorageView: View {
    @ObservedObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let volume = viewModel.selectedVolume {
                Text(volume.name)
                    .font(.headline)

                let usedFrac = volume.totalCapacity > 0
                    ? Double(volume.usedCapacity) / Double(volume.totalCapacity)
                    : 0
                let percent = Int(usedFrac * 100)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.12)).frame(height: 8)
                        Capsule()
                            .fill(usedFrac > 0.85 ? Color.red : Color.accentColor)
                            .frame(width: geo.size.width * usedFrac, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(L10n.menuBarPercent(percent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(volume.formattedUsed) / \(volume.formattedTotal)")
                        .font(.caption.monospacedDigit())
                }

                Divider()

                Label("\(volume.formattedAvailable) \(L10n.menuBarFree)", systemImage: "externaldrive")
                Label("\(volume.formattedUsed) \(L10n.menuBarUsed)", systemImage: "chart.pie.fill")
                if volume.purgeableCapacity > 0 {
                    Label("\(volume.formattedPurgeable) \(L10n.purgeableSpace)", systemImage: "sparkles")
                }

                Divider()

                Button(L10n.menuBarOpen) {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button(L10n.rescan) {
                    viewModel.rescanVolume()
                }
                Button(L10n.panelCleanup) {
                    viewModel.activePanel = .cleanup
                    NSApp.activate(ignoringOtherApps: true)
                }

                Divider()

                Button(L10n.menuDonate) {
                    viewModel.showDonation = true
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else {
                Text(L10n.analyzing)
                Button(L10n.menuBarOpen) {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}
