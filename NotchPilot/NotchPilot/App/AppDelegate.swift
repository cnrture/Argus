import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    let appState = AppState()
    let sessionStore = SessionStore()
    let settingsStore = SettingsStore()
    let hookInstaller = HookInstaller()
    private let socketServer = SocketServer()
    private let voiceManager = VoiceCommandManager()
    private var onboardingWindow: NSWindow?

    private static let onboardingCompletedKey = "onboardingCompleted"

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowController = NotchWindowController(appState: appState, settingsStore: settingsStore)
        windowController?.delegate = self
        windowController?.setup()

        settingsStore.onScreenChanged = { [weak self] in
            self?.windowController?.repositionPanel()
        }

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

        // Scan for existing Claude Code sessions
        scanForExistingSessions()

        // Voice commands
        setupVoiceCommands()

        // Boot animation
        windowController?.performBootAnimation()
    }

    private var processCheckTimer: Timer?

    private func scanForExistingSessions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let discovered = SessionScanner.findExistingSessions()
            guard !discovered.isEmpty else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for discovered in discovered {
                    let session = Session(id: discovered.sessionId, title: discovered.title)
                    session.cwd = discovered.cwd
                    if let pid = discovered.pid as Int? {
                        WindowJumper.detectOwnerApp(for: session, pid: pid)
                    }
                    self.sessionStore.addDiscoveredSession(session)
                    if self.appState.activeSessionId == nil {
                        self.appState.activeSessionId = discovered.sessionId
                    }
                }
                self.appState.panelState = .compact
                self.syncAppState()
                self.startProcessChecker()
            }
        }
    }

    private func startProcessChecker() {
        guard processCheckTimer == nil else { return }
        processCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.cleanupDeadSessions()
        }
    }

    private func cleanupDeadSessions() {
        let sessionIds = Array(sessionStore.sessions.keys)
        var changed = false

        for sessionId in sessionIds {
            // "existing-PID" formatındaki session'ları kontrol et
            if sessionId.hasPrefix("existing-"),
               let pidStr = sessionId.split(separator: "-").last,
               let pid = Int(pidStr) {
                if !isProcessAlive(pid: pid) {
                    sessionStore.removeSession(id: sessionId)
                    if appState.activeSessionId == sessionId {
                        appState.activeSessionId = sessionStore.sessions.keys.first
                    }
                    changed = true
                }
            }
        }

        if changed {
            if sessionStore.sessions.isEmpty {
                appState.panelState = .hidden
                processCheckTimer?.invalidate()
                processCheckTimer = nil
            }
            syncAppState()
        }
    }

    private func isProcessAlive(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private var settingsWindow: NSWindow?

    func openSettings() {
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settingsStore: settingsStore,
            hookInstaller: hookInstaller
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "NotchPilot Ayarları"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
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
        let results = hookInstaller.installHooks()
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedKey)

        for (agent, result) in results {
            switch result {
            case .installed, .alreadyInstalled:
                print("[NotchPilot] \(agent.displayName) hooks installed")
            case .failed(let error):
                print("[NotchPilot] \(agent.displayName) hook install failed: \(error)")
            }
        }

        onboardingWindow?.close()
        onboardingWindow = nil
    }
}

// MARK: - SocketServerDelegate

extension AppDelegate: SocketServerDelegate {
    func socketServer(_ server: SocketServer, didReceiveEvent event: HookEvent, respond: @escaping (SocketResponse) -> Void) {
        sessionStore.process(event: event, appState: appState, respond: respond)

        let sound = SoundManager.shared
        let configs = settingsStore.soundEvents

        switch event.event {
        case .sessionStart:
            sound.play(.sessionStarted, configs: configs)
        case .sessionEnd:
            sound.play(.sessionEnded, configs: configs)
        case .permissionRequest:
            let suppress = shouldSuppress(sessionId: event.sessionId)
            if !suppress { sound.play(.permissionNeeded, configs: configs) }
            windowController?.expandForPermission()
            startVoiceListeningIfNeeded()
        case .stop:
            let suppress = shouldSuppress(sessionId: event.sessionId)
            if !suppress {
                sound.play(.taskCompleted, configs: configs)
                windowController?.bounceOnComplete()
                if let sessionInfo = appState.sessions[event.sessionId] {
                    appState.completionSession = sessionInfo
                }
            }
        case .stopFailure:
            sound.play(.error, configs: configs)
            // ErrorCard is set by SessionStore
        case .notification:
            if event.data?.notificationType == "idle_prompt" {
                let suppress = shouldSuppress(sessionId: event.sessionId)
                if !suppress { sound.play(.idle, configs: configs) }
            }
        default:
            break
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
        // "Hepsine İzin Ver" → always: true ile respond et (Claude Code'a updatedPermissions gönderir)
        if let permission = appState.activePermission,
           let session = sessionStore.sessions[sessionId] {
            sessionStore.respondToPermission(eventId: permission.id, allow: true, always: true, session: session)
            syncAppState()
        }
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

    func notchWindowControllerDidRequestSettings(_ controller: NotchWindowController) {
        openSettings()
    }

    func notchWindowController(_ controller: NotchWindowController, didRequestJumpToSession sessionId: String) {
        if let session = sessionStore.sessions[sessionId] {
            WindowJumper.jumpToSession(session)
        }
    }

    private func setupVoiceCommands() {
        voiceManager.setEnabled(settingsStore.voiceCommandEnabled)
        voiceManager.onCommand = { [weak self] command in
            guard let self, let permission = self.appState.activePermission else { return }
            switch command {
            case .allow:
                self.windowController?.delegate?.notchWindowController(self.windowController!, didRespondToPermission: permission.id, allow: true)
            case .deny:
                self.windowController?.delegate?.notchWindowController(self.windowController!, didRespondToPermission: permission.id, allow: false)
            case .allowAll:
                if let activeId = self.appState.activeSessionId {
                    self.sessionStore.addAutoApproveRule(sessionId: activeId, toolName: permission.toolName)
                }
                self.windowController?.delegate?.notchWindowController(self.windowController!, didRespondToPermission: permission.id, allow: true)
            }
        }

        // Permission geldiğinde dinlemeye başla
        // (AppDelegate SocketServerDelegate'te zaten permission event'ini yakalıyor)
    }

    func startVoiceListeningIfNeeded() {
        if settingsStore.voiceCommandEnabled && appState.activePermission != nil {
            voiceManager.startListening()
        }
    }

    private func shouldSuppress(sessionId: String) -> Bool {
        guard let session = sessionStore.sessions[sessionId] else { return false }
        return SmartSuppress.isUserWatchingSession(session)
    }

    private func syncAppState() {
        // Trigger a no-op sync
        sessionStore.process(
            event: HookEvent(id: "sync", event: .notification, source: nil, timestamp: nil, sessionId: appState.activeSessionId ?? "", cwd: nil, data: nil),
            appState: appState,
            respond: { _ in }
        )
    }
}
