import SwiftUI

struct CompactView: View {
    let session: SessionInfo
    let sessionCount: Int
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    var hasPhysicalNotch: Bool = true
    var petStyle: PetStyle = .dot
    var accentColor: Color = .orange
    var showBorder: Bool = true
    var widthMultiplier: CGFloat = 1.5
    var cornerRadiusValue: CGFloat = 14
    var fontSizeValue: CGFloat = 12
    var horizontalOffset: CGFloat = 0

    private var isActive: Bool {
        session.status == .working || session.status == .waiting || session.status == .compacting
    }

    private var barWidth: CGFloat {
        let base = notchWidth * widthMultiplier
        return isActive ? base + 40 : base
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusPet(status: session.status, style: petStyle, accent: accentColor)

            Image(systemName: session.source.icon)
                .font(.system(size: max(fontSizeValue - 3, 8)))
                .foregroundStyle(session.source.color)

            if let statusText = session.lastStatusText {
                Text(statusText)
                    .font(.system(size: fontSizeValue - 1))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            } else {
                Text(session.title)
                    .font(.system(size: fontSizeValue, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: barWidth, height: notchHeight)
        .background(
            NotchShape(topCornerRadius: 0, bottomCornerRadius: cornerRadiusValue)
                .fill(.black)
        )
        .overlay(
            showBorder
                ? NotchShape(topCornerRadius: 0, bottomCornerRadius: cornerRadiusValue)
                    .stroke(accentColor.opacity(isActive ? 0.6 : 0.25), lineWidth: 1)
                : nil
        )
        .shadow(color: showBorder ? accentColor.opacity(isActive ? 0.3 : 0.1) : .black.opacity(0.5), radius: 8, y: 2)
        .glowEffect(isActive: isActive, color: accentColor)
        .pulseBorder(isActive: session.status == .working, color: accentColor)
        .offset(x: horizontalOffset)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isActive)
    }
}
