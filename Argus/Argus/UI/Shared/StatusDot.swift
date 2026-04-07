import SwiftUI

struct StatusDot: View {
    let status: SessionStatus

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.6), radius: isPulsing ? 6 : 2)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = shouldPulse }
            .onChange(of: status) { _, _ in isPulsing = shouldPulse }
    }

    private var color: Color {
        switch status {
        case .idle:       .green
        case .working:    .blue
        case .waiting:    .orange
        case .compacting: .blue
        case .error:      .red
        case .ended:      .gray
        }
    }

    private var shouldPulse: Bool {
        status == .working || status == .waiting || status == .compacting
    }
}
