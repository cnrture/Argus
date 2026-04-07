import AppKit
import SwiftUI

/// Sprite sheet'ten frame'leri keser ve NSImage array'i olarak sunar
final class SpriteSheetAnimator {
    let frames: [String: [NSImage]]  // "idle": [frame1, frame2, ...], "run": [...], etc.

    init?(sheetName: String, gridSize: CGSize = CGSize(width: 32, height: 32), layout: SpriteLayout) {
        // Bundle'da doğrudan Resources/ altında
        if let url = Bundle.main.url(forResource: sheetName, withExtension: "png"),
           let source = NSImage(contentsOf: url) {
            self.frames = Self.extractFrames(from: source, gridSize: gridSize, layout: layout)
            return
        }
        // Subdirectory ile dene
        if let url = Bundle.main.url(forResource: sheetName, withExtension: "png", subdirectory: "Pets/Cat"),
           let source = NSImage(contentsOf: url) {
            self.frames = Self.extractFrames(from: source, gridSize: gridSize, layout: layout)
            return
        }
        return nil
    }

    private static func extractFrames(from sheet: NSImage, gridSize: CGSize, layout: SpriteLayout) -> [String: [NSImage]] {
        var result: [String: [NSImage]] = [:]

        guard let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return result }

        let sheetWidth = CGFloat(cgImage.width)
        let sheetHeight = CGFloat(cgImage.height)
        let cols = Int(sheetWidth / gridSize.width)
        let rows = Int(sheetHeight / gridSize.height)

        for anim in layout.animations {
            var animFrames: [NSImage] = []
            for frameIndex in 0..<anim.frameCount {
                let col = (anim.startCol + frameIndex) % cols
                let row = anim.row

                guard row < rows, col < cols else { continue }

                let cropRect = CGRect(
                    x: CGFloat(col) * gridSize.width,
                    y: CGFloat(row) * gridSize.height,
                    width: gridSize.width,
                    height: gridSize.height
                )

                if let cropped = cgImage.cropping(to: cropRect) {
                    let img = NSImage(cgImage: cropped, size: NSSize(width: gridSize.width, height: gridSize.height))
                    animFrames.append(img)
                }
            }
            if !animFrames.isEmpty {
                result[anim.name] = animFrames
            }
        }

        return result
    }
}

struct SpriteLayout {
    let animations: [SpriteAnimation]

    struct SpriteAnimation {
        let name: String
        let row: Int
        let startCol: Int
        let frameCount: Int
    }
}

/// 128x256, 32x32 grid cat sprite sheet layout
let catSpriteLayout = SpriteLayout(animations: [
    .init(name: "idle",    row: 0, startCol: 0, frameCount: 4),
    .init(name: "sit",     row: 3, startCol: 0, frameCount: 3),
    .init(name: "run",     row: 4, startCol: 0, frameCount: 4),
    .init(name: "laydown", row: 5, startCol: 0, frameCount: 3),
    .init(name: "sleep",   row: 7, startCol: 0, frameCount: 2),
])
