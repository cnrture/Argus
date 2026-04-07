import SwiftUI

/// Compact bar üzerinde mouse yakınlığına göre parlama efekti
struct GlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: isActive ? 12 : 0)
            .overlay(
                isActive ?
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.0),
                                    color.opacity(0.08),
                                    color.opacity(0.0),
                                ],
                                startPoint: UnitPoint(x: phase - 0.3, y: 0),
                                endPoint: UnitPoint(x: phase + 0.3, y: 1)
                            )
                        )
                        .allowsHitTesting(false)
                    : nil
            )
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    phase = -0.3
                    withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            }
    }
}

/// Compact bar'ın working durumunda subtle pulse border efekti
struct PulseBorderModifier: ViewModifier {
    let isActive: Bool
    let color: Color

    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay(
                isActive ?
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(pulse ? 0.5 : 0.15), lineWidth: 1)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    : nil
            )
            .onAppear { pulse = isActive }
            .onChange(of: isActive) { _, v in pulse = v }
    }
}

extension View {
    func glowEffect(isActive: Bool, color: Color) -> some View {
        modifier(GlowModifier(isActive: isActive, color: color))
    }

    func pulseBorder(isActive: Bool, color: Color) -> some View {
        modifier(PulseBorderModifier(isActive: isActive, color: color))
    }
}
