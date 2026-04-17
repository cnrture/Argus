import SwiftUI

struct WelcomeStepsView: View {
    let appState: AppState
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let accentColor: Color
    var onInstallHooks: (() -> Void)?
    var onFinish: (() -> Void)?

    private let steps: [WelcomeStep] = [
        WelcomeStep(
            title: "Argus'a Hoş Geldin",
            subtitle: "AI agent'ların için notch üzerinde gerçek zamanlı kontrol paneli.",
            primaryLabel: "Devam Et",
            showsSkip: false
        ),
        WelcomeStep(
            title: "Hook'ları Kur",
            subtitle: "Claude Code, Codex, Gemini ve diğerleri için otomatik bağlantı.",
            primaryLabel: "Hook'ları Kur",
            showsSkip: true
        ),
        WelcomeStep(
            title: "Hazırsın",
            subtitle: "Bir AI agent çalıştır, Argus otomatik olarak bağlanacak.",
            primaryLabel: "Başlayalım",
            showsSkip: false
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Current step content
            Group {
                let step = steps[min(appState.welcomeStep, steps.count - 1)]
                VStack(spacing: 10) {
                    Text(step.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(step.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .id(appState.welcomeStep)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: 40, y: 0)),
                removal: .opacity.combined(with: .offset(x: -40, y: 0))
            ))

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == appState.welcomeStep ? accentColor : Color.white.opacity(0.25))
                        .frame(width: idx == appState.welcomeStep ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.welcomeStep)
                }
            }

            // Actions
            HStack(spacing: 10) {
                let step = steps[min(appState.welcomeStep, steps.count - 1)]
                if step.showsSkip {
                    Button(action: advance) {
                        Text("Atla")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.08), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button(action: handlePrimary) {
                    Text(step.primaryLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(accentColor, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .padding(.top, notchHeight)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.92))
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: appState.welcomeStep)
    }

    private func handlePrimary() {
        let step = steps[min(appState.welcomeStep, steps.count - 1)]
        if step.primaryLabel == "Hook'ları Kur" {
            onInstallHooks?()
        }
        advance()
    }

    private func advance() {
        if appState.welcomeStep >= steps.count - 1 {
            onFinish?()
        } else {
            appState.welcomeStep += 1
        }
    }
}

private struct WelcomeStep {
    let title: String
    let subtitle: String
    let primaryLabel: String
    let showsSkip: Bool
}
