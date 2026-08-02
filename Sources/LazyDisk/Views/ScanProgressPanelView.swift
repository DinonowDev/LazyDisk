import SwiftUI

/// Reusable progress panel with percentage label and gradient bar.
struct ScanProgressPanelView: View {
    let title: String
    let subtitle: String?
    let fraction: Double
    var detail: String?
    var onCancel: (() -> Void)?

    @State private var animatedFraction: Double = 0

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    private var percentLabel: String {
        String(format: "%.1f%%", clampedFraction * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Text(percentLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * animatedFraction), height: 10)
                }
            }
            .frame(height: 10)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if let detail, !detail.isEmpty {
                HStack(spacing: 6) {
                    CompactProgressView(size: 12)
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
            }

            if let onCancel {
                HStack {
                    Spacer()
                    Button(L10n.cancel, role: .cancel, action: onCancel)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        )
        .padding(.horizontal, 40)
        .onAppear {
            animatedFraction = clampedFraction
        }
        .onChange(of: fraction) { newValue in
            withAnimation(.linear(duration: 0.28)) {
                animatedFraction = min(max(newValue, 0), 1)
            }
        }
    }
}

extension ScanProgressPanelView {
    static func centered(
        title: String,
        subtitle: String? = nil,
        fraction: Double,
        detail: String? = nil,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        VStack {
            Spacer()
            ScanProgressPanelView(
                title: title,
                subtitle: subtitle,
                fraction: fraction,
                detail: detail,
                onCancel: onCancel
            )
            .frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
