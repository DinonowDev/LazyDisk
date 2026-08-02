import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scanParallelism: Double = Double(AppPreferences.load().scanParallelism)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(L10n.preferences)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L10n.cancel)
            }

            GroupBox(L10n.prefGeneral) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(L10n.prefCache, isOn: cacheBinding)
                    Toggle(L10n.prefHidden, isOn: hiddenBinding)

                    Picker(L10n.prefLanguage, selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.title).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(8)
            }

            GroupBox(L10n.prefScanning) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.prefScanParallel)
                        Spacer()
                        Text("\(Int(scanParallelism))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $scanParallelism, in: 1...16, step: 1)
                    Text(L10n.prefScanParallelHelp)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(8)
            }

            GroupBox(L10n.prefDisplay) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker(L10n.prefInterfaceMode, selection: interfaceModeBinding) {
                        ForEach(InterfaceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.interfaceMode == .professional {
                        ChartStylePicker(selection: Binding(
                            get: { viewModel.chartStyle },
                            set: { viewModel.setChartStyle($0) }
                        ))
                    } else {
                        ChartStylePicker(
                            selection: Binding(
                                get: { viewModel.chartStyle },
                                set: { viewModel.setChartStyle($0) }
                            ),
                            styles: [.rose, .sunburst]
                        )
                    }

                    Picker(L10n.prefDefaultSort, selection: $viewModel.sortOrder) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                }
                .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                Button(L10n.done) {
                    var prefs = AppPreferences.load()
                    prefs.scanParallelism = Int(scanParallelism)
                    prefs.save()
                    viewModel.savePreferences()
                    viewModel.refreshLanguage()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440, height: 460)
    }

    private var cacheBinding: Binding<Bool> {
        Binding(
            get: { AppPreferences.load().usePersistentCache },
            set: { newValue in
                var prefs = AppPreferences.load()
                prefs.usePersistentCache = newValue
                prefs.save()
            }
        )
    }

    private var hiddenBinding: Binding<Bool> {
        Binding(
            get: { AppPreferences.load().showHiddenFiles },
            set: { newValue in
                var prefs = AppPreferences.load()
                let changed = prefs.showHiddenFiles != newValue
                prefs.showHiddenFiles = newValue
                prefs.save()
                if changed {
                    viewModel.handleHiddenFilesPreferenceChanged()
                }
            }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppPreferences.load().language },
            set: { newValue in
                var prefs = AppPreferences.load()
                prefs.language = newValue
                prefs.save()
                viewModel.refreshLanguage()
            }
        )
    }

    private var interfaceModeBinding: Binding<InterfaceMode> {
        Binding(
            get: { viewModel.interfaceMode },
            set: { viewModel.setInterfaceMode($0) }
        )
    }
}
