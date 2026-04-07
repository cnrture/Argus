import AppKit
import SwiftUI

final class NotchWindowController {
    private var panel: NotchWindow?
    private var hostingView: PassThroughHostingView<AnyView>?
    private var screenObserver: ScreenObserver?
    private let appState: AppState
    private let eventMonitors = EventMonitors()
    private var currentNotchRect: CGRect = .zero
    private var currentScreenFrame: NSRect = .zero
    private var fullscreenHideTimer: Timer?
    private var fullscreenObserver: NSObjectProtocol?

    init(appState: AppState) {
        self.appState = appState
    }

    func setup() {
        createPanel()

        screenObserver = ScreenObserver { [weak self] in
            self?.repositionPanel()
        }

        setupEventMonitors()
        setupFullscreenObserver()
    }

    // MARK: - Panel Creation

    func createPanel() {
        let screen = ScreenSelector.select(preference: .automatic)
        let screenFrame = screen.frame
        currentScreenFrame = screenFrame
        let windowHeight: CGFloat = 750

        let windowFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )

        let notchSize = screen.notchSize
        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )
        currentNotchRect = deviceNotchRect

        let newPanel = NotchWindow(contentRect: windowFrame)

        let contentView = NotchContainerView(
            appState: appState,
            notchRect: deviceNotchRect,
            screenSize: screenFrame.size,
            onExpandChange: { [weak self] expanded in
                self?.onExpandChange(expanded)
            }
        )

        let hosting = PassThroughHostingView(rootView: AnyView(contentView))
        hosting.hitTestRect = expandedHitTestRect(for: deviceNotchRect)
        hosting.frame = NSRect(origin: .zero, size: windowFrame.size)

        newPanel.contentView = hosting

        panel?.close()
        panel = newPanel
        hostingView = hosting

        newPanel.orderFrontRegardless()
    }

    func repositionPanel() {
        createPanel()
    }

    // MARK: - Event Monitors

    private func setupEventMonitors() {
        eventMonitors.onMouseMove = { [weak self] screenPoint in
            self?.handleMouseMove(screenPoint)
        }
        eventMonitors.onMouseDown = { [weak self] screenPoint in
            self?.handleMouseDown(screenPoint)
        }
        eventMonitors.startAll()
    }

    private func handleMouseMove(_ screenPoint: NSPoint) {
        guard appState.panelState != .hidden else { return }

        let panelPoint = convertScreenToPanel(screenPoint)

        // Fullscreen trigger zone: top 5pt
        if appState.isFullscreen {
            let isInTriggerZone = screenPoint.y >= currentScreenFrame.maxY - 5
            if isInTriggerZone && !appState.isExpanded {
                showInFullscreen()
                return
            }
        }

        // Hover detection over compact bar area
        let hoverRect = compactHoverRect()
        let expandedRect = expandedHoverRect()

        let isInHoverArea = appState.isExpanded
            ? expandedRect.contains(panelPoint)
            : hoverRect.contains(panelPoint)

        if isInHoverArea && !appState.isExpanded {
            expand()
        } else if !isInHoverArea && appState.isExpanded {
            collapse()
        }
    }

    private func handleMouseDown(_ screenPoint: NSPoint) {
        guard appState.isExpanded else { return }

        let panelPoint = convertScreenToPanel(screenPoint)
        let expandedRect = expandedHoverRect()

        if !expandedRect.contains(panelPoint) {
            collapse()
        }
    }

    // MARK: - Expand / Collapse

    private func expand() {
        appState.isExpanded = true
        panel?.ignoresMouseEvents = false
        updateHitTestRect()
        fullscreenHideTimer?.invalidate()
    }

    private func collapse() {
        appState.isExpanded = false
        panel?.ignoresMouseEvents = true
        updateHitTestRect()
    }

    private func onExpandChange(_ expanded: Bool) {
        if expanded {
            expand()
        } else {
            collapse()
        }
    }

    // MARK: - Fullscreen

    private func setupFullscreenObserver() {
        fullscreenObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreen()
        }
    }

    private func checkFullscreen() {
        guard let screen = NSScreen.main else { return }
        let isFS = NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            && screen.frame == screen.visibleFrame
        appState.isFullscreen = isFS
    }

    private func showInFullscreen() {
        expand()
        fullscreenHideTimer?.invalidate()
        fullscreenHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self, self.appState.isFullscreen else { return }
            self.collapse()
        }
    }

    // MARK: - Boot Animation

    func performBootAnimation() {
        guard appState.hasActiveSessions else { return }
        appState.isBootAnimating = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.expand()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.collapse()
            self?.appState.isBootAnimating = false
        }
    }

    // MARK: - Bounce on Complete

    func bounceOnComplete() {
        guard !appState.isExpanded else { return }
        // Minimal scale bounce via panel frame manipulation
        guard let panel else { return }
        let originalFrame = panel.frame

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.075
            panel.animator().setFrame(
                originalFrame.insetBy(dx: -2, dy: -2),
                display: true
            )
        }) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.075
                panel.animator().setFrame(originalFrame, display: true)
            })
        }
    }

    // MARK: - Geometry Helpers

    private func convertScreenToPanel(_ screenPoint: NSPoint) -> NSPoint {
        guard let panel else { return .zero }
        let panelFrame = panel.frame
        return NSPoint(
            x: screenPoint.x - panelFrame.origin.x,
            y: panelFrame.maxY - screenPoint.y
        )
    }

    private func compactHoverRect() -> CGRect {
        let notchWidth = currentNotchRect.width
        let barWidth = notchWidth * 1.5
        let barHeight: CGFloat = 32
        let centerX = currentNotchRect.midX
        return CGRect(
            x: centerX - barWidth / 2 - 10,
            y: currentNotchRect.height - 5,
            width: barWidth + 20,
            height: barHeight + 15
        )
    }

    private func expandedHoverRect() -> CGRect {
        let notchWidth = currentNotchRect.width
        let expandedWidth = min(notchWidth * 3, 600)
        let expandedHeight: CGFloat = 400
        let centerX = currentNotchRect.midX
        return CGRect(
            x: centerX - expandedWidth / 2 - 10,
            y: 0,
            width: expandedWidth + 20,
            height: currentNotchRect.height + expandedHeight + 10
        )
    }

    private func expandedHitTestRect(for notchRect: CGRect) -> CGRect {
        let notchWidth = notchRect.width
        let expandedWidth = min(notchWidth * 3, 600)
        let centerX = notchRect.midX
        return CGRect(
            x: centerX - expandedWidth / 2,
            y: 0,
            width: expandedWidth,
            height: 500
        )
    }

    private func updateHitTestRect() {
        if appState.isExpanded {
            hostingView?.hitTestRect = expandedHitTestRect(for: currentNotchRect)
        } else {
            hostingView?.hitTestRect = .zero
        }
    }
}
