import SwiftUI

struct OnboardingView: View {
    let onSetupHooks: () -> Void
    let onSkip: () -> Void

    @State private var isInstalling = false
    @State private var installResult: String?

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("NotchPilot'a Hoş Geldin!")
                .font(.title2.bold())

            Text("Claude Code hook'larını otomatik kurmak ister misin?")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Bu işlem ~/.claude/settings.json dosyasına NotchPilot hook'larını ekler. Mevcut ayarlarına dokunulmaz ve yedek alınır.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let result = installResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.contains("Hata") ? .red : .green)
            }

            HStack(spacing: 16) {
                Button("Hayır, elle kuracağım") {
                    onSkip()
                }
                .buttonStyle(.bordered)

                Button(action: {
                    isInstalling = true
                    onSetupHooks()
                }) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Kur")
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(isInstalling)
            }
        }
        .padding(32)
        .frame(width: 420)
    }
}
