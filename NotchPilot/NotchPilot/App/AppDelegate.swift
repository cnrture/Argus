import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    let appState = AppState()
    let sessionStore = SessionStore()
    private let socketServer = SocketServer()
    private let hookInstaller = HookInstaller()
    private var onboardingWindow: NSWindow?

    private static let onboardingCompletedKey = "onboardingCompleted"

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = NotchWindowController(appState: appState)
        windowController?.delegate = self
        windowController?.setup()

        // Start socket server
        socketServer.delegate = self
        do {
            try socketServer.start()
        } catch {
            print("[NotchPilot] Socket server start failed: \(error)")
        }

        // Install bridge binary
        _ = hookInstaller.installBridge()

        // Onboarding or auto-setup
        if !UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) {
            showOnboarding()
        } else if !hookInstaller.hooksAreInstalled() {
            _ = hookInstaller.installHooks()
        }

        // Boot animation
        windowController?.performBootAnimation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        let onboardingView = OnboardingView(
            onSetupHooks: { [weak self] in
                self?.performHookSetup()
            },
            onSkip: { [weak self] in
                UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchPilot"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    private func performHookSetup() {
        let result = hookInstaller.installHooks()
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)

        switch result {
        case .installed, .alreadyInstalled:
            print("[NotchPilot] Hooks installed successfully")
        case .failed(let error):
            print("[NotchPilot] Hook installation failed: \(error)")
        }

        onboardingWindow?.close()
        onboardingWindow = nil
    }
}

// MARK: - SocketServerDelegate

extension AppDelegate: SocketServerDelegate {
    func socketServer(_ server: SocketServer, didReceiveEvent event: HookEvent, respond: @escaping (SocketResponse) -> Void) {
        sessionStore.process(event: event, appState: appState, respond: respond)

        // Auto-expand for permission requests
        if event.event == .permissionRequest {
            windowController?.expandForPermission()
        }

        // Bounce on complete
        if event.event == .stop {
            windowController?.bounceOnComplete()
        }
    }
}

// MARK: - NotchWindowControllerDelegate

extension AppDelegate: NotchWindowControllerDelegate {
    func notchWindowController(_ controller: NotchWindowController, didRespondToPermission eventId: String, allow: Bool) {
        if let activeId = appState.activeSessionId,
           let session = sessionStore.sessions[activeId] {
            sessionStore.respondToPermission(eventId: eventId, allow: allow, session: session)
            syncAppState()
        }
    }

    func notchWindowController(_ controller: NotchWindowController, didAutoApprove toolName: String, forSession sessionId: String) {
        sessionStore.addAutoApproveRule(sessionId: sessionId, toolName: toolName)
    }

    func notchWindowController(_ controller: NotchWindowController, didAnswerQuestion eventId: String, answer: String) {
        sessionStore.respondToQuestion(eventId: eventId, answer: answer)
        if let activeId = appState.activeSessionId {
            sessionStore.sessions[activeId]?.pendingQuestion = nil
        }
        syncAppState()
    }

    func notchWindowController(_ controller: NotchWindowController, didRespondToPlan eventId: String, approve: Bool, feedback: String?) {
        let answer = approve ? "approve" : "deny"
        let fullAnswer = [answer, feedback].compactMap { $0 }.joined(separator: ": ")
        sessionStore.respondToQuestion(eventId: eventId, answer: fullAnswer)
        if let activeId = appState.activeSessionId {
            sessionStore.sessions[activeId]?.pendingPlan = nil
        }
        syncAppState()
    }

    private func syncAppState() {
        // Trigger a no-op sync
        sessionStore.process(
            event: HookEvent(id: "sync", event: .notification, timestamp: nil, sessionId: appState.activeSessionId ?? "", cwd: nil, data: nil),
            appState: appState,
            respond: { _ in }
        )
    }
}
