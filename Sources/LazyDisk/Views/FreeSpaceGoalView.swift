import SwiftUI

struct FreeSpaceGoalView: View {
    @EnvironmentObject var viewModel: DiskBrowserViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            panelHeader(
                title: L10n.goalTitle,
                subtitle: viewModel.selectedVolume.map { "\(L10n.menuBarFree): \($0.formattedAvailable)" } ?? ""
            )
            .padding(.horizontal)

            if let volume = viewModel.selectedVolume {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(L10n.goalTarget)
                        Spacer()
                        Text(ByteFormatter.string(from: Int64(viewModel.freeSpaceGoalGB * 1_073_741_824)))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }

                    Slider(value: $viewModel.freeSpaceGoalGB, in: 1...200, step: 1)
                        .onChange(of: viewModel.freeSpaceGoalGB) { _ in
                            viewModel.saveFreeSpaceGoal()
                        }

                    let targetBytes = Int64(viewModel.freeSpaceGoalGB * 1_073_741_824)
                    let needed = max(0, targetBytes - volume.availableCapacity)
                    let progress = min(1, Double(volume.availableCapacity) / Double(max(targetBytes, 1)))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.goalProgress)
                            .font(.headline)
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))% · \(ByteFormatter.string(from: volume.availableCapacity)) / \(ByteFormatter.string(from: targetBytes))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if needed > 0 {
                        Text(L10n.goalNeedMore(ByteFormatter.string(from: needed)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)

                        Button(L10n.goalSuggest) {
                            viewModel.suggestItemsForGoal()
                        }
                        .buttonStyle(.borderedProminent)

                        if !viewModel.goalSuggestions.isEmpty {
                            List(viewModel.goalSuggestions) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text(item.formattedSize)
                                        .font(.system(size: 11, design: .monospaced))
                                    Button {
                                        viewModel.addToCollector(item)
                                    } label: {
                                        Image(systemName: "plus.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                    } else {
                        Label(L10n.goalReached, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.headline)
                    }
                }
                .padding()
            }

            Spacer()
        }
    }
}
