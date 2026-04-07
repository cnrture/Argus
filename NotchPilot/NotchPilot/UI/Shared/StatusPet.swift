import SwiftUI

enum PetStyle: String, CaseIterable, Codable {
    case dot
    case cat
    case dog
    case bird
    case robot
    case ghost
    case alien

    var displayName: String {
        switch self {
        case .dot:   L10n["pet.dot"]
        case .cat:   L10n["pet.cat"]
        case .dog:   L10n["pet.dog"]
        case .bird:  L10n["pet.bird"]
        case .robot: L10n["pet.robot"]
        case .ghost: L10n["pet.ghost"]
        case .alien: L10n["pet.alien"]
        }
    }

    func pixels(for status: SessionStatus) -> [[UInt8]] {
        switch self {
        case .dot:   return []
        case .cat:   return PixelPets.cat(status)
        case .dog:   return PixelPets.dog(status)
        case .bird:  return PixelPets.bird(status)
        case .robot: return PixelPets.robot(status)
        case .ghost: return PixelPets.ghost(status)
        case .alien: return PixelPets.alien(status)
        }
    }

    func animationFrames(for status: SessionStatus) -> [[[UInt8]]] {
        switch self {
        case .dot: return []
        case .cat:   return PixelPets.catFrames(status)
        case .dog:   return PixelPets.dogFrames(status)
        case .bird:  return PixelPets.birdFrames(status)
        case .robot: return PixelPets.robotFrames(status)
        case .ghost: return PixelPets.ghostFrames(status)
        case .alien: return PixelPets.alienFrames(status)
        }
    }

    func palette(for status: SessionStatus, accent: Color) -> [Color] {
        let statusHint: Color = switch status {
        case .waiting:    .orange
        case .error:      .red
        case .ended:      .gray
        default:          accent
        }
        // 0=clear, 1=primary, 2=dark/shadow, 3=highlight, 4=statusHint
        return [.clear, accent, accent.opacity(0.4), .white, statusHint]
    }
}

// MARK: - Pixel Pet View

struct StatusPet: View {
    let status: SessionStatus
    let style: PetStyle
    var accent: Color = .orange

    @State private var frame = 0
    @State private var bounce = false
    @State private var timer: Timer?

    var body: some View {
        if style == .dot {
            StatusDot(status: status)
        } else {
            PixelArtView(
                pixels: currentFrame,
                palette: style.palette(for: status, accent: accent),
                pixelSize: 2
            )
            .frame(width: 16, height: 16)
            .offset(y: bounce ? -1.5 : 0)
            .scaleEffect(status == .error ? (bounce ? 0.9 : 1.0) : 1.0)
            .rotationEffect(status == .idle ? .degrees(bounce ? 5 : -5) : .zero)
            .animation(animationType, value: bounce)
            .onAppear { startAnimation() }
            .onChange(of: status) { _, _ in startAnimation() }
            .onDisappear { timer?.invalidate() }
        }
    }

    private var currentFrame: [[UInt8]] {
        let frames = style.animationFrames(for: status)
        let idx = frame % max(frames.count, 1)
        return frames.isEmpty ? style.pixels(for: status) : frames[idx]
    }

    private var animationType: Animation {
        switch status {
        case .working:    .easeInOut(duration: 0.35).repeatForever(autoreverses: true)
        case .waiting:    .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        case .error:      .easeInOut(duration: 0.3).repeatForever(autoreverses: true)
        case .idle:       .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        default:          .default
        }
    }

    private func startAnimation() {
        timer?.invalidate()
        bounce = false

        let shouldAnimate = status == .working || status == .waiting || status == .error || status == .idle
        if shouldAnimate {
            bounce = true
            let interval: TimeInterval = status == .working ? 0.4 : 0.8
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                frame += 1
            }
        }
    }
}

// MARK: - Pixel Art Renderer

struct PixelArtView: View {
    let pixels: [[UInt8]]
    let palette: [Color]
    let pixelSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let rows = pixels.count
            guard rows > 0 else { return }
            let cols = pixels[0].count

            let pw = size.width / CGFloat(cols)
            let ph = size.height / CGFloat(rows)
            let ps = min(pw, ph)

            let offsetX = (size.width - ps * CGFloat(cols)) / 2
            let offsetY = (size.height - ps * CGFloat(rows)) / 2

            for row in 0..<rows {
                for col in 0..<pixels[row].count {
                    let idx = Int(pixels[row][col])
                    guard idx > 0, idx < palette.count else { continue }
                    let rect = CGRect(
                        x: offsetX + CGFloat(col) * ps,
                        y: offsetY + CGFloat(row) * ps,
                        width: ps,
                        height: ps
                    )
                    context.fill(Path(rect), with: .color(palette[idx]))
                }
            }
        }
    }
}

// MARK: - 8-Bit Pet Sprites (8x8 grids)
// 0=transparent, 1=primary, 2=dark/shadow, 3=white/highlight, 4=accent

struct PixelPets {
    static func cat(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,1,0,0,0,0,1,0],
            [0,1,1,0,0,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        case .waiting: return [
            [0,1,0,0,0,0,1,0],
            [0,1,1,0,0,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,2,2,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,0,0,0,0,0,0],
        ]
        case .error: return [
            [0,1,0,0,0,0,1,0],
            [0,1,1,0,0,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,2,2,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,0,0,0,0,0,0],
        ]
        default: return [ // idle / ended
            [0,1,0,0,0,0,1,0],
            [0,1,1,0,0,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        }
    }

    static func dog(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,0,1,0,0,1,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,2,2,1,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        case .waiting: return [
            [1,0,0,0,0,0,0,1],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,0,0,0,0,0,0],
        ]
        default: return [
            [0,0,1,0,0,1,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        }
    }

    static func bird(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        case .waiting: return [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,3,1,1,3,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,2,0,0,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        default: return [
            [0,0,0,1,1,0,0,0],
            [0,0,1,1,1,1,0,0],
            [0,1,2,1,1,2,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,1,1,1,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,0,1,1,0,0,0],
            [0,0,1,0,0,1,0,0],
        ]
        }
    }

    static func robot(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,0,0,3,3,0,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1],
            [0,1,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        case .waiting: return [
            [0,0,0,4,4,0,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,4,1,1,4,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        default: return [
            [0,0,0,3,3,0,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        }
    }

    static func ghost(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,1,3,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,1,1,0,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        case .waiting: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,3,1,3,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,2,2,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,1,1,0,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        default: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,0],
            [0,1,0,1,1,0,1,0],
            [0,1,0,0,0,0,1,0],
        ]
        }
    }

    static func alien(_ s: SessionStatus) -> [[UInt8]] {
        switch s {
        case .working, .compacting: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,3,1,1,3,1,1],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,0,1,2,2,1,0,0],
            [0,0,1,0,0,1,0,0],
            [0,1,0,0,0,0,1,0],
        ]
        case .waiting: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,3,3,3,3,1,1],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,0,0,1,0,0],
            [0,1,0,0,0,0,1,0],
        ]
        default: return [
            [0,0,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,0],
            [1,1,2,1,1,2,1,1],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,0,0],
            [0,0,1,0,0,1,0,0],
            [0,1,0,0,0,0,1,0],
        ]
        }
    }

    // MARK: - Animation Frames (2 frames per state for all pets)
    // Frame animation: idle=zzz blink, working=run cycle, error=cry, waiting=look around

    static func catFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .idle: return [ // Blink/sleep
            cat(s),
            [[0,1,0,0,0,0,1,0],[0,1,1,0,0,1,1,0],[0,1,1,1,1,1,1,0],[0,1,2,2,2,2,1,0],[0,1,1,1,1,1,1,0],[0,0,1,1,1,1,0,0],[0,0,0,1,1,0,0,0],[0,0,1,0,0,1,0,0]]
        ]
        case .working: return [ // Run
            cat(s),
            [[0,1,0,0,0,0,1,0],[0,1,1,0,0,1,1,0],[0,1,1,1,1,1,1,0],[0,1,3,1,1,3,1,0],[0,1,1,1,1,1,1,0],[0,0,1,1,1,1,0,0],[0,0,1,0,1,0,0,0],[0,1,0,0,0,1,0,0]]
        ]
        case .error: return [ // Cry
            cat(s),
            [[0,1,0,0,0,0,1,0],[0,1,1,0,0,1,1,0],[0,1,1,1,1,1,1,0],[0,1,2,1,1,2,1,0],[0,1,4,1,1,4,1,0],[0,0,1,2,2,1,0,0],[0,0,0,1,1,0,0,0],[0,0,0,0,0,0,0,0]]
        ]
        default: return [cat(s)]
        }
    }

    static func dogFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .idle: return [
            dog(s),
            [[0,0,1,0,0,1,0,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,0],[0,1,2,2,2,2,1,0],[0,1,1,1,1,1,1,0],[0,0,1,1,1,1,0,0],[0,0,1,1,1,1,0,0],[0,0,1,0,0,1,0,0]]
        ]
        case .working: return [
            dog(s),
            [[0,0,1,0,0,1,0,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,0],[0,1,3,1,1,3,1,0],[0,1,1,2,2,1,0,0],[0,0,1,1,1,1,0,0],[0,1,0,0,0,0,1,0],[0,0,0,0,0,0,0,0]]
        ]
        default: return [dog(s)]
        }
    }

    static func birdFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .working: return [ // Flap wings
            bird(s),
            [[0,0,0,1,1,0,0,0],[0,0,1,1,1,1,0,0],[1,1,3,1,1,3,1,1],[0,0,1,1,1,1,0,0],[0,0,1,1,1,1,0,0],[0,0,0,1,1,0,0,0],[0,0,0,1,1,0,0,0],[0,0,1,0,0,1,0,0]]
        ]
        default: return [bird(s)]
        }
    }

    static func robotFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .working: return [ // Antenna blink
            robot(s),
            [[0,0,0,4,4,0,0,0],[0,1,1,1,1,1,1,0],[0,1,3,1,1,3,1,0],[0,1,1,1,1,1,1,0],[1,1,1,1,1,1,1,1],[0,1,1,2,2,1,1,0],[0,1,1,1,1,1,1,0],[0,1,0,0,0,0,1,0]]
        ]
        default: return [robot(s)]
        }
    }

    static func ghostFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .idle: return [ // Float
            ghost(s),
            [[0,0,0,0,0,0,0,0],[0,0,1,1,1,1,0,0],[0,1,1,1,1,1,1,0],[0,1,2,1,1,2,1,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,0],[0,1,0,1,1,0,1,0],[0,1,0,0,0,0,1,0]]
        ]
        case .working: return [
            ghost(s),
            [[0,0,1,1,1,1,0,0],[0,1,1,1,1,1,1,0],[0,1,1,3,3,1,1,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,1,0],[0,1,0,1,1,0,1,0],[0,0,1,0,0,1,0,0]]
        ]
        default: return [ghost(s)]
        }
    }

    static func alienFrames(_ s: SessionStatus) -> [[[UInt8]]] {
        switch s {
        case .working: return [ // Eye pulse
            alien(s),
            [[0,0,1,1,1,1,0,0],[0,1,1,1,1,1,1,0],[1,1,4,1,1,4,1,1],[1,1,1,1,1,1,1,1],[0,1,1,1,1,1,1,0],[0,0,1,2,2,1,0,0],[0,0,1,0,0,1,0,0],[0,1,0,0,0,0,1,0]]
        ]
        default: return [alien(s)]
        }
    }
}
