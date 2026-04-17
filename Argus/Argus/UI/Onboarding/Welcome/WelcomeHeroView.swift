import SwiftUI

struct WelcomeHeroView: View {
    let flow: WelcomeFlowState
    let screenSize: CGSize
    let notchCenter: CGPoint
    let notchSize: CGSize
    let tint: Color
    let onGatherComplete: () -> Void

    @State private var meshTime: Double = 0

    var body: some View {
        ZStack {
            // Ambient mesh gradient backdrop (macOS 15+)
            AmbientBackdrop(phase: flow.phase, time: meshTime)
                .ignoresSafeArea()

            // Radial glow halo behind logo
            RadialGradient(
                colors: [
                    tint.opacity(haloOpacity * 0.55),
                    tint.opacity(0)
                ],
                center: .center,
                startRadius: 0,
                endRadius: haloRadius
            )
            .frame(width: haloRadius * 2, height: haloRadius * 2)
            .position(x: logoX, y: logoY)
            .blendMode(.screen)
            .animation(.easeOut(duration: 0.9), value: flow.phase)

            // Particle trail (active during gather phase, follows logo)
            ParticleTrail(
                origin: CGPoint(x: logoX, y: logoY),
                active: flow.phase == .gather,
                tint: tint
            )
            .opacity(flow.phase == .gather ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: flow.phase)

            // Logo
            LogoMark()
                .frame(width: logoSize, height: logoSize)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .shadow(color: .black.opacity(0.35), radius: logoShadowRadius, x: 0, y: logoShadowY)
                .position(x: logoX, y: logoY)
                .animation(heroAnimation, value: flow.phase)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                meshTime = 1
            }
        }
        .onChange(of: flow.phase) { _, newPhase in
            if newPhase == .gather {
                DispatchQueue.main.asyncAfter(deadline: .now() + flow.gatherDuration) {
                    onGatherComplete()
                }
            }
        }
    }

    // MARK: - Geometry per phase

    private var logoX: CGFloat {
        switch flow.phase {
        case .idle, .emerge: return screenSize.width / 2
        case .gather, .morph, .reveal, .steps, .done: return notchCenter.x
        }
    }

    private var logoY: CGFloat {
        switch flow.phase {
        case .idle, .emerge: return screenSize.height / 2
        case .gather, .morph, .reveal, .steps, .done: return notchCenter.y
        }
    }

    private var logoScale: CGFloat {
        switch flow.phase {
        case .idle: return 0.3
        case .emerge: return 1.0
        case .gather: return 0.18
        case .morph, .reveal, .steps, .done: return 0.0
        }
    }

    private var logoSize: CGFloat {
        180
    }

    private var logoOpacity: Double {
        switch flow.phase {
        case .idle: return 0
        case .emerge, .gather: return 1
        case .morph: return 0.3
        case .reveal, .steps, .done: return 0
        }
    }

    private var haloRadius: CGFloat {
        switch flow.phase {
        case .idle: return 40
        case .emerge: return 260
        case .gather: return 120
        case .morph, .reveal, .steps, .done: return 20
        }
    }

    private var haloOpacity: Double {
        switch flow.phase {
        case .idle: return 0
        case .emerge: return 1
        case .gather: return 0.7
        case .morph, .reveal, .steps, .done: return 0
        }
    }

    private var logoShadowRadius: CGFloat {
        flow.phase == .emerge ? 40 : 12
    }

    private var logoShadowY: CGFloat {
        flow.phase == .emerge ? 20 : 6
    }

    private var heroAnimation: Animation {
        if WelcomeFlowState.reduceMotion {
            return .easeInOut(duration: 0.35)
        }
        switch flow.phase {
        case .emerge: return .spring(response: 0.95, dampingFraction: 0.68)
        case .gather: return .spring(response: 1.0, dampingFraction: 0.82)
        case .morph: return .easeIn(duration: 0.25)
        default: return .easeInOut(duration: 0.4)
        }
    }
}

// MARK: - Mesh backdrop

private struct AmbientBackdrop: View {
    let phase: WelcomePhase
    let time: Double

    var body: some View {
        Group {
            if #available(macOS 15.0, *) {
                meshGradient
            } else {
                fallbackGradient
            }
        }
        .opacity(backdropOpacity)
        .animation(.easeInOut(duration: 0.6), value: phase)
    }

    @available(macOS 15.0, *)
    private var meshGradient: some View {
        let drift = Float(time) * 0.08 - 0.04
        let points: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
            SIMD2(0, 0.5 + drift), SIMD2(0.5, 0.5), SIMD2(1, 0.5 - drift),
            SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1)
        ]
        let colors: [Color] = [
            .black, Color(red: 0.05, green: 0.05, blue: 0.10), .black,
            Color(red: 0.08, green: 0.04, blue: 0.14),
            Color(red: 0.12, green: 0.07, blue: 0.22),
            Color(red: 0.05, green: 0.05, blue: 0.12),
            .black, Color(red: 0.04, green: 0.04, blue: 0.08), .black
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.10),
                Color(red: 0.10, green: 0.06, blue: 0.18),
                Color(red: 0.04, green: 0.04, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backdropOpacity: Double {
        switch phase {
        case .idle: return 0
        case .emerge: return 0.92
        case .gather: return 0.78
        case .morph: return 0.3
        case .reveal, .steps, .done: return 0
        }
    }
}

// MARK: - Logo mark

private struct LogoMark: View {
    var body: some View {
        if let icon = NSApp.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback: styled "A" glyph
            Text("A")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}
