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
            // Sol: Pet
            StatusPet(status: session.status, style: petStyle, accent: accentColor)

            // Orta: Metin
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

            // Sag: Durum gostergesi
            StatusIndicator(status: session.status, color: accentColor)
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

// MARK: - Status Indicator (sag taraf)

private struct StatusIndicator: View {
    let status: SessionStatus
    let color: Color

    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        switch status {
        case .working, .compacting:
            // Donen spinner
            Image(systemName: "arrow.trianglehead.2.clockwise")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: spin)
                .onAppear { spin = true }

        case .waiting:
            // Nabiz noktasi
            Circle()
                .fill(.orange)
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .opacity(pulse ? 1 : 0.4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

        case .idle:
            // Kucuk tire
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.2))
                .frame(width: 10, height: 2)

        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.red)

        case .ended:
            EmptyView()
        }
    }
}
