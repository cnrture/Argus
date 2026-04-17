import SwiftUI

struct ParticleTrail: View {
    let origin: CGPoint
    let active: Bool
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { context in
            Canvas { ctx, size in
                guard active else { return }
                let now = context.date.timeIntervalSinceReferenceDate
                let particles = Self.particles(now: now, origin: origin)
                for p in particles {
                    let rect = CGRect(
                        x: p.position.x - p.size / 2,
                        y: p.position.y - p.size / 2,
                        width: p.size,
                        height: p.size
                    )
                    var color = tint
                    color = color.opacity(p.alpha)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }

    private static func particles(now: TimeInterval, origin: CGPoint) -> [Particle] {
        let count = 24
        var out: [Particle] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let seed = Double(i) * 0.7182
            let phase = (now + seed).truncatingRemainder(dividingBy: 1.2) / 1.2
            let age = phase
            let angle = (seed * 6.2831).truncatingRemainder(dividingBy: 6.2831)
            let speed = 20 + (seed.truncatingRemainder(dividingBy: 1)) * 40
            let dx = cos(angle) * speed * age
            let dy = sin(angle) * speed * age + (age * age * 60)
            let alpha = max(0, 0.9 - age * 1.1)
            let size = max(1.5, 5 - age * 4)
            out.append(Particle(
                position: CGPoint(x: origin.x + dx, y: origin.y + dy),
                alpha: alpha,
                size: size
            ))
        }
        return out
    }

    private struct Particle {
        let position: CGPoint
        let alpha: Double
        let size: Double
    }
}
