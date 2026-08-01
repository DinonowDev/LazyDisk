import SwiftUI

struct BreadcrumbView: View {
    let breadcrumbs: [URL]
    let volumeName: String
    var onNavigate: (URL) -> Void

    var body: some View {
        Group {
            if breadcrumbs.isEmpty {
                Text("—")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, url in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }

                            Button {
                                onNavigate(url)
                            } label: {
                                HStack(spacing: 5) {
                                    if index == 0 {
                                        Image(systemName: "internaldrive.fill")
                                            .font(.system(size: 9))
                                    }

                                    Text(displayName(for: url, index: index))
                                        .font(.system(size: 11, weight: index == breadcrumbs.count - 1 ? .semibold : .medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(index == breadcrumbs.count - 1
                                              ? Color.accentColor.opacity(0.14)
                                              : Color.primary.opacity(0.05))
                                }
                                .foregroundStyle(index == breadcrumbs.count - 1 ? Color.accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 28)
    }

    private func displayName(for url: URL, index: Int) -> String {
        if index == 0 { return volumeName }
        let name = url.lastPathComponent
        return name.isEmpty ? "/" : name
    }
}
