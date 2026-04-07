import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let settingsStore: SettingsStore
    var onOpenSettings: () -> Void
    var onToggleSound: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Argus")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            Divider().padding(.vertical, 4)

            if appState.sessions.isEmpty {
                Text("Aktif oturum yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            } else {
                Text("\(appState.sessions.count) aktif oturum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)

                ForEach(appState.sortedSessions) { session in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(session.status))
                            .frame(width: 6, height: 6)
                        Text(session.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        Text(formatTime(since: session.startTime))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
            }

            Divider().padding(.vertical, 4)

            Button(action: onToggleSound) {
                HStack {
                    Image(systemName: settingsStore.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                    Text(settingsStore.soundEnabled ? "Sesi Kapat" : "Sesi Aç")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Ayarlar...")
                    Spacer()
                    Text("⌘,")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider().padding(.vertical, 4)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack {
                    Text("Çıkış")
                    Spacer()
                    Text("⌘Q")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 240)
    }

    private func statusColor(_ status: SessionStatus) -> Color {
        switch status {
        case .idle: .green
        case .working, .compacting: .blue
        case .waiting: .orange
        case .error: .red
        case .ended: .gray
        }
    }

    private func formatTime(since date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%d:%02d", m, s)
    }
}
