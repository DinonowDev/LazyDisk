import SwiftUI

struct ScanningView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    @State private var pulseAnimation = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            RadialGradient(colors: [Color.accentColor.opacity(0.08), Color.clear], center: .center, startRadius: 0, endRadius: 400)
                .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()
                scanningIcon

                VStack(spacing: 10) {
                    Text(L10n.scanningDiskTitle)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    if let volume = viewModel.selectedVolume {
                        Text(volume.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                ScanProgressPanelView(
                    title: viewModel.scanProgress.isEmpty ? L10n.scanning : viewModel.scanProgress,
                    subtitle: viewModel.scanCurrentFolder.isEmpty ? nil : viewModel.scanCurrentFolder,
                    fraction: viewModel.scanProgressFraction,
                    detail: nil
                )
                .frame(maxWidth: 520)

                Spacer()

                Button(L10n.cancel, role: .cancel) {
                    viewModel.cancelScan()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
        }
    }

    private var scanningIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 3)
                .frame(width: 100, height: 100)
                .scaleEffect(pulseAnimation ? 1.15 : 1)
                .opacity(pulseAnimation ? 0 : 0.8)

            Circle()
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 2)
                .frame(width: 80, height: 80)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { pulseAnimation = true }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}
