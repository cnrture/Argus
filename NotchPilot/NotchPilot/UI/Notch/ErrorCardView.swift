import SwiftUI

struct ErrorCardView: View {
    let errorType: String
    let errorMessage: String
    let sessionTitle: String
    let notchWidth: CGFloat
    var onDismiss: (() -> Void)?

    @State private var appear = false

    private var cardWidth: CGFloat {
        min(notchWidth * 2.5, 480)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Error icon
            ZStack {
                Circle()
                    .fill(.red.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: errorIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .scaleEffect(appear ? 1.0 : 0.3)
            }
            .padding(.top, 14)

            Text(errorTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text(sessionTitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))

            Text(errorMessage)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)

            Button(action: { onDismiss?() }) {
                Text("Tamam")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 16)
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
                .stroke(.red.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .red.opacity(0.15), radius: 12, y: 4)
        .scaleEffect(appear ? 1.0 : 0.8)
        .opacity(appear ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }

    private var errorIcon: String {
        switch errorType {
        case "rate_limit":             "hourglass"
        case "authentication_failed":  "lock.shield"
        case "billing_error":          "creditcard.trianglebadge.exclamationmark"
        case "max_output_tokens":      "text.badge.xmark"
        default:                       "exclamationmark.triangle.fill"
        }
    }

    private var errorTitle: String {
        switch errorType {
        case "rate_limit":             "Rate Limit"
        case "authentication_failed":  "Kimlik Dogrulama Hatasi"
        case "billing_error":          "Fatura Hatasi"
        case "server_error":           "Sunucu Hatasi"
        case "max_output_tokens":      "Token Limiti Asildi"
        default:                       "Hata"
        }
    }
}
