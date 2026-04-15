import SwiftUI

struct QuestionView: View {
    let session: SessionInfo
    let question: QuestionEvent
    let notchWidth: CGFloat
    var onAnswer: (String) -> Void

    @State private var freeTextAnswer = ""
    @FocusState private var isTextFieldFocused: Bool

    private var expandedWidth: CGFloat {
        min(notchWidth * 3, 600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            questionHeader
            questionBody
            Spacer().frame(height: 4)
        }
        .padding(.bottom, 14)
        .frame(width: expandedWidth)
        .background(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 24)
                .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 24)
                .stroke(.orange.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear { isTextFieldFocused = !question.hasOptions }
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusDot(status: .waiting)
                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("— \(L10n["question.label"])")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Text(question.question)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var questionBody: some View {
        if question.hasOptions {
            optionsView
        } else {
            freeTextView
        }
    }

    private var optionsView: some View {
        VStack(spacing: 6) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                Button(action: { onAnswer(option) }) {
                    HStack {
                        Text("\(index + 1). \(option)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        if index < 3 {
                            Text("⌘\(index + 1)")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 0.5))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var freeTextView: some View {
        HStack(spacing: 8) {
            TextField(L10n["question.placeholder"], text: $freeTextAnswer)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.1), lineWidth: 0.5))
                .focused($isTextFieldFocused)
                .onSubmit { submitFreeText() }

            Button(action: submitFreeText) {
                Text(L10n["question.submit"])
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.orange.opacity(0.3)))
                    .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(freeTextAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
    }

    private func submitFreeText() {
        let trimmed = freeTextAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onAnswer(trimmed)
        }
    }
}
