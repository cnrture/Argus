import SwiftUI

struct CompactView: View {
    let session: SessionInfo
    let sessionCount: Int
    let notchWidth: CGFloat
    var petStyle: PetStyle = .dot
    var accentColor: Color = .orange
    var showBorder: Bool = true

    private var isActive: Bool {
        session.status == .working || session.status == .waiting || session.status == .compacting
    }

    private var barWidth: CGFloat {
        let base = notchWidth * 1.5
        return isActive ? base + 40 : base
    }

    private var barHeight: CGFloat { 32 }

    var body: some View {
        HStack(spacing: 8) {
            StatusPet(status: session.status, style: petStyle, accent: accentColor)

            // Agent icon
            Image(systemName: session.source.icon)
                .font(.system(size: 9))
                .foregroundStyle(session.source.color)

            if let statusText = session.lastStatusText {
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text(session.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: barWidth, height: barHeight)
        .background(
            NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                .fill(.black)
        )
        .overlay(
            showBorder
                ? NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                    .stroke(accentColor.opacity(isActive ? 0.6 : 0.25), lineWidth: 1)
                : nil
        )
        .shadow(color: showBorder ? accentColor.opacity(isActive ? 0.3 : 0.1) : .black.opacity(0.5), radius: 8, y: 2)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isActive)
    }
}
