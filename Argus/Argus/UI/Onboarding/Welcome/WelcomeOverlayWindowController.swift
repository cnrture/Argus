import AppKit
import SwiftUI

final class WelcomeOverlayWindowController {
    private let flow: WelcomeFlowState
    private weak var settingsStore: SettingsStore?
    private let onHandoffToNotch: () -> Void
    private let onComplete: () -> Void
    private let onSkip: () -> Void
    private var window: WelcomeOverlayWindow?
    private var escMonitor: Any?

    init(flow: WelcomeFlowState,
         settingsStore: SettingsStore?,
         onHandoffToNotch: @escaping () -> Void,
         onComplete: @escaping () -> Void,
         onSkip: @escaping () -> Void) {
        self.flow = flow
        self.settingsStore = settingsStore
        self.onHandoffToNotch = onHandoffToNotch
        self.onComplete = onComplete
        self.onSkip = onSkip
    }

    func start() {
        let preference: ScreenSelection
        if let name = settingsStore?.selectedScreenName {
            preference = .specific(ScreenIdentifier(displayID: nil, localizedName: name))
        } else {
            preference = .automatic
        }
        let screen = ScreenSelector.select(preference: preference)
        let frame = screen.frame
        let notchSize = screen.notchSize

        let overlay = WelcomeOverlayWindow(contentRect: frame)
        let rootView = WelcomeOverlayRoot(
            flow: flow,
            screenSize: frame.size,
            // SwiftUI uses top-left origin; the notch sits at the top edge.
            notchCenterInWindow: CGPoint(
                x: frame.width / 2,
                y: notchSize.height / 2
            ),
            notchSize: notchSize,
            tint: settingsStore?.accentColor ?? .orange,
            onHandoffReady: { [weak self] in
                self?.handoff()
            }
        )
        overlay.contentView = NSHostingView(rootView: rootView)
        overlay.orderFront(nil)
        window = overlay

        // ESC to skip
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.skip()
                return nil
            }
            return event
        }

        // Kick off phase 1 on next runloop so SwiftUI picks up the initial .idle state
        // before we flip to .emerge — this makes the spring animate from the start.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flow.phase = .emerge
            DispatchQueue.main.asyncAfter(deadline: .now() + self.flow.emergeDuration) { [weak self] in
                guard let self, self.flow.isActive else { return }
                self.flow.phase = .gather
            }
        }
    }

    private func handoff() {
        guard flow.isActive else { return }
        flow.phase = .morph
        onHandoffToNotch()

        // Fade overlay then remove it from the window list so it no longer
        // eats mouse events for the notch panel underneath.
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            self.window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.flow.phase = .reveal
            self?.window?.orderOut(nil)
            self?.finish()
        })
    }

    private func skip() {
        window?.orderOut(nil)
        onSkip()
        finish()
    }

    private func finish() {
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
        onComplete()
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
    }
}

private struct WelcomeOverlayRoot: View {
    let flow: WelcomeFlowState
    let screenSize: CGSize
    let notchCenterInWindow: CGPoint
    let notchSize: CGSize
    let tint: Color
    let onHandoffReady: () -> Void

    var body: some View {
        WelcomeHeroView(
            flow: flow,
            screenSize: screenSize,
            notchCenter: notchCenterInWindow,
            notchSize: notchSize,
            tint: tint,
            onGatherComplete: onHandoffReady
        )
        .allowsHitTesting(false)
    }
}
