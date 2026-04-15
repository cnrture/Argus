import SwiftUI

struct IdlePromptView: View {
    let sessionTitle: String
    let notchWidth: CGFloat
    var onJump: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var pulse = false

    private var cardWidth: CGFloat {
        min(notchWidth * 2, 400)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Pulsing indicator
            Circle()
                .fill(.orange)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .shadow(color: .orange.opacity(0.5), radius: pulse ? 6 : 2)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n["status.waitingForResponse"])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Text(sessionTitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button(action: { onJump?() }) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 9))
                    Text(L10n["action.go"])
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(.orange.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: cardWidth)
        .background(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 14)
                .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 14)
                .stroke(.orange.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear { pulse = true }
    }
}
