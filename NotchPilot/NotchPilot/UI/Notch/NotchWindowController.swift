import AppKit
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let allowPermission = Self("allowPermission", default: .init(.y, modifiers: .command))
    static let denyPermission = Self("denyPermission", default: .init(.n, modifiers: .command))
    static let togglePanel = Self("togglePanel", default: .init(.p, modifiers: [.command, .shift]))
    static let questionOption1 = Self("questionOption1", default: .init(.one, modifiers: .command))
    static let questionOption2 = Self("questionOption2", default: .init(.two, modifiers: .command))
    static let questionOption3 = Self("questionOption3", default: .init(.three, modifiers: .command))
}

final class NotchWindowController {
    private var panel: NotchWindow?
    private var hostingView: PassThroughHostingView<AnyView>?
    private var screenObserver: ScreenObserver?
    private let appState: AppState
    private var settingsStore: SettingsStore?
    private let eventMonitors = EventMonitors()
    private var currentNotchRect: CGRect = .zero
    private var currentScreenFrame: NSRect = .zero
    private var fullscreenHideTimer: Timer?
    private var fullscreenObserver: NSObjectProtocol?
    weak var delegate: NotchWindowControllerDelegate?

    init(appState: AppState, settingsStore: SettingsStore? = nil) {
        self.appState = appState
        self.settingsStore = settingsStore
    }

    func setup() {
        createPanel()

        screenObserver = ScreenObserver { [weak self] in
            self?.repositionPanel()
        }

        setupEventMonitors()
        setupFullscreenObserver()
        setupKeyboardShortcuts()
    }

    // MARK: - Panel Creation

    func createPanel() {
        let preference: ScreenSelection
        if let screenName = settingsStore?.selectedScreenName {
            let id = ScreenIdentifier(displayID: nil, localizedName: screenName)
            preference = .specific(id)
        } else {
            preference = .automatic
        }
        let screen = ScreenSelector.select(preference: preference)
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
            settingsStore: settingsStore,
            notchRect: deviceNotchRect,
            screenSize: screenFrame.size,
            onExpandChange: { [weak self] expanded in
                self?.onExpandChange(expanded)
            },
            onPermissionAllow: { [weak self] eventId in
                self?.onPermissionResponse(eventId: eventId, allow: true)
            },
            onPermissionDeny: { [weak self] eventId in
                self?.onPermissionResponse(eventId: eventId, allow: false)
            },
            onAutoApprove: { [weak self] sessionId, toolName in
                self?.onAutoApprove(sessionId: sessionId, toolName: toolName)
            },
            onQuestionAnswer: { [weak self] eventId, answer in
                self?.delegate?.notchWindowController(self!, didAnswerQuestion: eventId, answer: answer)
                self?.collapse()
            },
            onPlanApprove: { [weak self] eventId, feedback in
                self?.delegate?.notchWindowController(self!, didRespondToPlan: eventId, approve: true, feedback: feedback)
                self?.collapse()
            },
            onPlanReject: { [weak self] eventId, feedback in
                self?.delegate?.notchWindowController(self!, didRespondToPlan: eventId, approve: false, feedback: feedback)
                self?.collapse()
            },
            onOpenSettings: { [weak self] in
                self?.collapse()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.delegate?.notchWindowControllerDidRequestSettings(self!)
                }
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onJumpToSession: { [weak self] sessionId in
                self?.delegate?.notchWindowController(self!, didRequestJumpToSession: sessionId)
                self?.collapse()
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

        // Fullscreen: panel hidden, only show on hover trigger zone (top 5pt)
        if appState.isFullscreen {
            let isInTriggerZone = screenPoint.y >= currentScreenFrame.maxY - 5
            if isInTriggerZone {
                showForPermissionInFullscreen()
            }
            // Don't expand on hover in fullscreen — only show compact briefly
            return
        }

        // Hover detection over compact bar area
        let hoverRect = compactHoverRect()
        let expandedRect = expandedHoverRect()

        let isInHoverArea = appState.isExpanded
            ? expandedRect.contains(panelPoint)
            : hoverRect.contains(panelPoint)

        // Compact bar hover glow
        let isNearCompact = hoverRect.contains(panelPoint)
        if isNearCompact != appState.isHovered {
            appState.isHovered = isNearCompact
        }

        if isInHoverArea && !appState.isExpanded {
            expand()
        } else if !isInHoverArea && appState.isExpanded && !hasPendingInteraction {
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
        // Active app change
        fullscreenObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreen()
        }
        // Also check on app activation changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreen()
        }
    }

    private func checkFullscreen() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let isSelf = frontApp?.bundleIdentifier == Bundle.main.bundleIdentifier

        var isFS = false
        if !isSelf, let screen = NSScreen.main {
            // Yöntem 1: Menu bar gizli mi?
            let menuBarVisible = screen.frame.height != screen.visibleFrame.height
                || screen.visibleFrame.origin.y != screen.frame.origin.y
            if !menuBarVisible {
                isFS = true
            }

            // Yöntem 2: CGWindowListCopyWindowInfo ile frontmost app'ın penceresi ekranı kaplıyor mu?
            if !isFS, let pid = frontApp?.processIdentifier {
                if let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
                    for win in windows {
                        guard let ownerPID = win[kCGWindowOwnerPID as String] as? Int32,
                              ownerPID == pid,
                              let bounds = win[kCGWindowBounds as String] as? [String: CGFloat],
                              let winW = bounds["Width"], let winH = bounds["Height"] else { continue }
                        if winW >= screen.frame.width && winH >= screen.frame.height {
                            isFS = true
                            break
                        }
                    }
                }
            }
        }

        let wasFullscreen = appState.isFullscreen
        appState.isFullscreen = isFS

        let showInFS = settingsStore?.showInFullscreen ?? true

        if isFS && !showInFS {
            panel?.alphaValue = 0
        } else if !isFS {
            panel?.alphaValue = 1
        }
    }

    func showForPermissionInFullscreen() {
        // Temporarily show panel for permission/question even in fullscreen
        panel?.alphaValue = 1
        fullscreenHideTimer?.invalidate()
        fullscreenHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self, self.appState.isFullscreen, !self.hasPendingInteraction else { return }
            self.panel?.alphaValue = 0
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
        let barWidth = notchWidth + 72  // compact bar genişliği ile eşleş
        let centerX = currentNotchRect.midX
        return CGRect(
            x: centerX - barWidth / 2,
            y: 0,
            width: barWidth,
            height: currentNotchRect.height
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
        // NSView coordinates: origin is bottom-left
        // Panel height is 750, content starts from top (y=750 in NSView)
        // Expanded content spans from top down ~500pt
        return CGRect(
            x: centerX - expandedWidth / 2,
            y: 250, // 750 - 500 = bottom boundary in NSView coords
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

    /// Kullanıcı yanıtı bekleyen permission/question/plan varsa true
    private var hasPendingInteraction: Bool {
        appState.activePermission != nil ||
        appState.activeQuestion != nil ||
        appState.activePlan != nil
    }

    // MARK: - Permission Auto-Expand

    func expandForPermission() {
        if appState.isFullscreen {
            showForPermissionInFullscreen()
        }
        expand()
    }

    // MARK: - Permission Handling

    private func onPermissionResponse(eventId: String, allow: Bool) {
        delegate?.notchWindowController(self, didRespondToPermission: eventId, allow: allow)
        collapse()
    }

    private func onAutoApprove(sessionId: String, toolName: String) {
        delegate?.notchWindowController(self, didAutoApprove: toolName, forSession: sessionId)
    }

    // MARK: - Keyboard Shortcuts

    func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .allowPermission) { [weak self] in
            guard let self,
                  let permission = self.appState.activePermission else { return }
            self.onPermissionResponse(eventId: permission.id, allow: true)
        }

        KeyboardShortcuts.onKeyUp(for: .denyPermission) { [weak self] in
            guard let self,
                  let permission = self.appState.activePermission else { return }
            self.onPermissionResponse(eventId: permission.id, allow: false)
        }

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            guard let self else { return }
            if self.appState.isExpanded {
                self.collapse()
            } else {
                self.expand()
            }
        }

        // Cmd+1/2/3 for question options
        for (shortcut, index) in [
            (KeyboardShortcuts.Name.questionOption1, 0),
            (KeyboardShortcuts.Name.questionOption2, 1),
            (KeyboardShortcuts.Name.questionOption3, 2),
        ] {
            KeyboardShortcuts.onKeyUp(for: shortcut) { [weak self] in
                guard let self,
                      let question = self.appState.activeQuestion,
                      index < question.options.count else { return }
                self.delegate?.notchWindowController(self, didAnswerQuestion: question.id, answer: question.options[index])
                self.collapse()
            }
        }
    }
}

protocol NotchWindowControllerDelegate: AnyObject {
    func notchWindowController(_ controller: NotchWindowController, didRespondToPermission eventId: String, allow: Bool)
    func notchWindowController(_ controller: NotchWindowController, didAutoApprove toolName: String, forSession sessionId: String)
    func notchWindowController(_ controller: NotchWindowController, didAnswerQuestion eventId: String, answer: String)
    func notchWindowController(_ controller: NotchWindowController, didRespondToPlan eventId: String, approve: Bool, feedback: String?)
    func notchWindowControllerDidRequestSettings(_ controller: NotchWindowController)
    func notchWindowController(_ controller: NotchWindowController, didRequestJumpToSession sessionId: String)
}
