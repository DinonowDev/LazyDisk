import SwiftUI

struct RootView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        Group {
            switch viewModel.appPhase {
            case .welcome:
                WelcomeView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .permissions:
                PermissionsView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

            case .scanning:
                ScanningView()
                    .transition(.opacity)

            case .ready:
                if viewModel.interfaceMode == .simple {
                    SimpleContentView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    ContentView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.appPhase)
        .applyRTLLayout()
        .id(viewModel.languageRevision)
        .onAppear {
            if viewModel.appPhase == .welcome {
                viewModel.prepareWelcome()
            }
        }
        .sheet(isPresented: $viewModel.showDonation) {
            DonationDialogView()
        }
        .sheet(isPresented: $viewModel.showPreferences) {
            PreferencesView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showAbout) {
            AboutView()
        }
    }
}
