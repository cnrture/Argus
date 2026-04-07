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
        case .dot:   "Nokta"
        case .cat:   "Kedi"
        case .dog:   "Kopek"
        case .bird:  "Kus"
        case .robot: "Robot"
        case .ghost: "Hayalet"
        case .alien: "Uzayli"
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

    @State private var bounce = false

    var body: some View {
        if style == .dot {
            StatusDot(status: status)
        } else {
            PixelArtView(
                pixels: style.pixels(for: status),
                palette: style.palette(for: status, accent: accent),
                pixelSize: 2
            )
            .frame(width: 16, height: 16)
            .offset(y: bounce ? -1 : 0)
            .animation(
                shouldAnimate
                    ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                    : .default,
                value: bounce
            )
            .onAppear { bounce = shouldAnimate }
            .onChange(of: status) { _, _ in bounce = shouldAnimate }
        }
    }

    private var shouldAnimate: Bool {
        status == .working || status == .waiting
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
}
