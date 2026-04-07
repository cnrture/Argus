import SwiftUI

struct ExpandedOverviewView: View {
    let appState: AppState
    let notchWidth: CGFloat

    private var expandedWidth: CGFloat {
        min(notchWidth * 3, 600)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("NotchPilot")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Session list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(appState.sortedSessions) { session in
                        SessionCard(session: session)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 300)

            Divider()
                .background(.white.opacity(0.1))
                .padding(.vertical, 8)

            // Bottom bar
            HStack {
                Button(action: {}) {
                    Label("Ses", systemImage: "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {}) {
                    Label("Ayarlar", systemImage: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: expandedWidth)
        .background(
            NotchShape(
                topCornerRadius: 19,
                bottomCornerRadius: 24
            )
            .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(
                topCornerRadius: 19,
                bottomCornerRadius: 24
            )
            .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
