import SwiftUI

struct CompactView: View {
    let session: SessionInfo
    let sessionCount: Int
    let notchWidth: CGFloat

    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    private var isActive: Bool {
        session.status == .working || session.status == .waiting || session.status == .compacting
    }

    // Dynamic Island style: expand when active
    private var barWidth: CGFloat {
        let base = notchWidth * 1.5
        return isActive ? base + 40 : base
    }

    private var barHeight: CGFloat { 32 }

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: session.status)

            Text(session.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            if sessionCount > 1 {
                Text("(\(sessionCount))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(formattedTime)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .frame(width: barWidth, height: barHeight)
        .background(
            NotchShape(
                topCornerRadius: 6,
                bottomCornerRadius: 14
            )
            .fill(.black)
        )
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isActive)
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
    }

    private var formattedTime: String {
        let total = Int(elapsedTime)
        let minutes = total / 60
        let seconds = total % 60
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
