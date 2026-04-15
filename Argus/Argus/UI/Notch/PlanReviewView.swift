import SwiftUI

struct PlanReviewView: View {
    let session: SessionInfo
    let plan: PlanEvent
    let notchWidth: CGFloat
    var onApprove: (String?) -> Void
    var onReject: (String?) -> Void

    @State private var feedback = ""
    @State private var showApproveButton = false
    @State private var showRejectButton = false

    private var expandedWidth: CGFloat {
        min(notchWidth * 3, 600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                StatusDot(status: .waiting)
                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("— \(L10n["plan.reviewLabel"])")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Plan markdown
            ScrollView(.vertical, showsIndicators: false) {
                MarkdownText(text: plan.planMarkdown)
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: 300)

            // Feedback field
            TextField(L10n["plan.feedbackPlaceholder"], text: $feedback)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.1), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)

            // Action buttons with staggered reveal
            HStack(spacing: 12) {
                Spacer()

                Button(action: {
                    let fb = feedback.isEmpty ? nil : feedback
                    onReject(fb)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(L10n["plan.reject"])
                            .font(.system(size: 12, weight: .medium))
                        Text("(⌘N)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.red.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .opacity(showRejectButton ? 1 : 0)

                Button(action: {
                    let fb = feedback.isEmpty ? nil : feedback
                    onApprove(fb)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(L10n["plan.approve"])
                            .font(.system(size: 12, weight: .medium))
                        Text("(⌘Y)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.green.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.green.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .opacity(showApproveButton ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: expandedWidth)
        .background(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 24)
                .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 24)
                .stroke(.orange.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) { showRejectButton = true }
            withAnimation(.easeOut(duration: 0.2).delay(0.15)) { showApproveButton = true }
        }
    }
}
