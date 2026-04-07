import SwiftUI
import AppKit

struct DeskPet: View {
    let status: SessionStatus
    let petStyle: PetStyle
    let accentColor: Color
    let spriteSheet: String
    var petSize: CGFloat = 32

    @State private var frameIndex = 0
    @State private var jumpY: CGFloat = 0
    @State private var fallAngle: Double = 0
    @State private var timer: Timer?
    @State private var animFrames: [NSImage] = []
    @State private var allFrames: [String: [NSImage]] = [:]

    var body: some View {
        Group {
            if frameIndex < animFrames.count {
                Image(nsImage: animFrames[frameIndex])
                    .interpolation(.none)
                    .resizable()
                    .frame(width: petSize, height: petSize)
            } else {
                Text("🐱")
                    .font(.system(size: 18))
            }
        }
        .offset(y: jumpY)
        .rotationEffect(.degrees(fallAngle))
        .onAppear {
            loadSprites()
            startAnimation()
        }
        .onChange(of: spriteSheet) { _, _ in
            loadSprites()
        }
        .onChange(of: status) { _, newStatus in
            switchAnimation()
            if newStatus == .error { triggerFall() }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var currentAnimName: String {
        switch status {
        case .working, .compacting: "idle"   // Yürüme animasyonu, hız farkı timer'da
        case .idle:                 "idle"
        case .waiting:              "sit"
        case .error:                "laydown"
        case .ended:                "sleep"
        }
    }

    private func loadSprites() {
        guard let animator = SpriteSheetAnimator(
            sheetName: spriteSheet,
            gridSize: CGSize(width: 32, height: 32),
            layout: catSpriteLayout
        ) else { return }

        allFrames = animator.frames
        switchAnimation()
    }

    private func switchAnimation() {
        animFrames = allFrames[currentAnimName] ?? []
        frameIndex = 0
    }

    private func startAnimation() {
        timer?.invalidate()
        fallAngle = 0
        jumpY = 0

        let interval: TimeInterval = status == .working ? 0.15 : 0.3
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if !animFrames.isEmpty {
                frameIndex = (frameIndex + 1) % animFrames.count
            }
        }
    }

    private func triggerFall() {
        timer?.invalidate()
        switchAnimation()
        withAnimation(.easeIn(duration: 0.4)) {
            fallAngle = 90
            jumpY = 5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                fallAngle = 0
                jumpY = 0
            }
            startAnimation()
        }
    }
}
