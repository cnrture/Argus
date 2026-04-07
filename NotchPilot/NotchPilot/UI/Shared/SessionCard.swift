import SwiftUI

struct SessionCard: View {
    let session: SessionInfo
    var isCompact: Bool = false

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusDot(status: session.status)

                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(formattedTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if !isCompact {
                if session.isIdle {
                    Text("15 dk+ hareketsiz")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                } else if let lastTool = session.lastToolName {
                    Text("Son: \(lastTool)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(session.isIdle ? 0.03 : 0.06))
        )
        .opacity(session.isIdle ? 0.6 : 1.0)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var formattedTime: String {
        let total = Int(elapsedTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        elapsedTime = Date().timeIntervalSince(session.startTime)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(session.startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
