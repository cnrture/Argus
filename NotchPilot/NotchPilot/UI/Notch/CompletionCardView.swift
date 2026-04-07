import SwiftUI

struct CompletionCardView: View {
    let session: SessionInfo
    let notchWidth: CGFloat
    var onDismiss: (() -> Void)?
    var onJump: (() -> Void)?

    @State private var appear = false
    @State private var shimmer = false

    private var cardWidth: CGFloat {
        min(notchWidth * 2.5, 480)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.green)
                    .scaleEffect(appear ? 1.0 : 0.3)
            }
            .padding(.top, 14)

            // Session info
            HStack(spacing: 6) {
                Image(systemName: session.source.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(session.source.color)
                Text(session.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Last message
            if let text = session.lastStatusText {
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Duration
            Text("Tamamlandi")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.green.opacity(0.7))

            // Jump button
            Button(action: { onJump?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 10))
                    Text("Terminal'e Git")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: cardWidth)
        .background(
            NotchShape(topCornerRadius: 14, bottomCornerRadius: 20)
                .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(topCornerRadius: 14, bottomCornerRadius: 20)
                .stroke(.green.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .green.opacity(0.15), radius: 12, y: 4)
        .scaleEffect(appear ? 1.0 : 0.8)
        .opacity(appear ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appear = true
            }
            // Auto dismiss after 4s
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                onDismiss?()
            }
        }
    }
}
