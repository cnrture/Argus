import AppKit
import SwiftUI

@Observable
final class DeskPetState {
    var positionX: CGFloat = 400
    var facingRight: Bool = true
}

final class DeskPetWindowController {
    private var panel: NSPanel?
    private let appState: AppState
    private let settingsStore: SettingsStore
    private let petState = DeskPetState()

    private var direction: CGFloat = 1
    private var moveTimer: Timer?

    private let petSize: CGFloat = 24

    init(appState: AppState, settingsStore: SettingsStore) {
        self.appState = appState
        self.settingsStore = settingsStore
    }

    private var cachedDockBounds: CGRect = .zero

    func setup() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let dockRect = dockBounds(screen)
        cachedDockBounds = dockRect

        petState.positionX = dockRect.width / 2

        // Panel dock'un hemen üstünde
        // dockRect.origin AppleScript top-left koordinat, x doğru ama y çevrilmeli
        let petH = CGFloat(settingsStore.deskPetSize)
        let panelFrame = panelRect(dockRect: dockRect, petH: petH)
        lastPetSize = settingsStore.deskPetSize

        let newPanel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.ignoresMouseEvents = true

        // View bir kere oluştur — state reactive olarak güncellenir
        let contentView = DeskPetContainer(
            appState: appState,
            settingsStore: settingsStore,
            petState: petState
        )
        newPanel.contentView = NSHostingView(rootView: contentView)

        panel = newPanel
        newPanel.orderFrontRegardless()
        startMoving()
    }

    func show() {
        panel?.orderFrontRegardless()
        startMoving()
    }

    func hide() {
        moveTimer?.invalidate()
        panel?.orderOut(nil)
    }

    private func startMoving() {
        moveTimer?.invalidate()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    private var lastPetSize: Double = 32
    private var lastPetType: String = "cat"

    private func updatePosition() {
        let dock = cachedDockBounds
        guard dock.width > 0 else { return }

        // Pet size veya tipi değişince panel'i güncelle
        if settingsStore.deskPetSize != lastPetSize || settingsStore.deskPetType != lastPetType {
            lastPetSize = settingsStore.deskPetSize
            lastPetType = settingsStore.deskPetType
            updatePanelFrame()
        }
        let status = appState.activeSession?.status ?? .idle

        let speed: CGFloat
        switch status {
        case .working, .compacting: speed = 2.0
        case .waiting:              speed = 0.3
        case .idle:                 speed = 0.8
        case .error:                speed = 0
        case .ended:                speed = 0
        }

        petState.positionX += direction * speed

        let margin: CGFloat = 16
        if petState.positionX > dock.width - margin {
            direction = -1
            petState.facingRight = false
        } else if petState.positionX < margin {
            direction = 1
            petState.facingRight = true
        }
    }

    private func panelRect(dockRect: CGRect, petH: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let screenFrame = screen.frame
        let dockH = dockHeight(screen)
        let panelHeight = petH + 16

        // Köpek sprite'ları 64px native, kedi 32px — offset oranları farklı
        let isDog = settingsStore.deskPetType == "dog"
        let offsetRatio: CGFloat = isDog ? 0.15 : 0.3
        let panelY = screenFrame.origin.y + dockH - (petH * offsetRatio)

        return NSRect(x: dockRect.origin.x, y: panelY, width: dockRect.width, height: panelHeight)
    }

    private func updatePanelFrame() {
        guard let panel, let screen = NSScreen.main else { return }
        let petH = CGFloat(settingsStore.deskPetSize)
        let rect = panelRect(dockRect: cachedDockBounds, petH: petH)
        panel.setFrame(rect, display: true)
    }

    private func dockHeight(_ screen: NSScreen) -> CGFloat {
        screen.visibleFrame.origin.y - screen.frame.origin.y
    }

    private func dockBounds(_ screen: NSScreen) -> CGRect {
        // Accessibility API ile gerçek dock frame'i al
        if let realBounds = getDockFrameViaAccessibility() {
            return realBounds
        }

        // Fallback
        let screenFrame = screen.frame
        let dockH = dockHeight(screen)
        if dockH > 0 {
            let dockWidth = min(screenFrame.width * 0.55, 800)
            let x = screenFrame.origin.x + (screenFrame.width - dockWidth) / 2
            return CGRect(x: x, y: screenFrame.origin.y, width: dockWidth, height: dockH)
        }
        let w: CGFloat = 600
        let x = screenFrame.origin.x + (screenFrame.width - w) / 2
        return CGRect(x: x, y: screenFrame.origin.y, width: w, height: 0)
    }

    private func getDockFrameViaAccessibility() -> CGRect? {
        let script = """
        tell application "System Events"
            tell process "Dock"
                set dockList to list 1
                set dockPos to position of dockList
                set dockSize to size of dockList
                return (item 1 of dockPos as text) & "," & (item 2 of dockPos as text) & "," & (item 1 of dockSize as text) & "," & (item 2 of dockSize as text)
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !output.isEmpty else { return nil }
            let parts = output.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 4 else { return nil }
            return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
        } catch {
            return nil
        }
    }
}

// MARK: - Container (created once, updates reactively)

struct DeskPetContainer: View {
    let appState: AppState
    let settingsStore: SettingsStore
    let petState: DeskPetState

    var body: some View {
        GeometryReader { geo in
            if appState.hasActiveSessions && settingsStore.deskPetEnabled && !(appState.isFullscreen && !settingsStore.showInFullscreen) {
                let status = appState.activeSession?.status ?? .idle
                DeskPet(
                    status: status,
                    petStyle: settingsStore.petStyle,
                    accentColor: settingsStore.accentColor,
                    spriteSheet: settingsStore.deskPetSpriteSheet,
                    petSize: CGFloat(settingsStore.deskPetSize)
                )
                .scaleEffect(x: petState.facingRight ? 1 : -1, y: 1)
                .position(x: petState.positionX, y: geo.size.height / 2)
            }
        }
    }
}
