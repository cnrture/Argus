import AppKit
import AVFoundation
import Foundation

final class SoundManager {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]
    private var enabled = true
    private var volume: Float = 0.7

    // macOS system sound mapping for each trigger
    private let systemSoundNames: [SoundTrigger: String] = [
        .sessionStarted:   "Blow",
        .sessionEnded:     "Bottle",
        .permissionNeeded: "Ping",
        .questionAsked:    "Pop",
        .planReady:        "Purr",
        .taskCompleted:    "Glass",
        .error:            "Basso",
    ]

    func configure(enabled: Bool, volume: Float) {
        self.enabled = enabled
        self.volume = volume
    }

    func play(_ trigger: SoundTrigger, configs: [SoundEventConfig]) {
        guard enabled else { return }
        guard let config = configs.first(where: { $0.eventType == trigger }),
              config.enabled else { return }

        // 1. Custom sound file
        if let custom = config.customSoundURL, FileManager.default.fileExists(atPath: custom.path) {
            playFile(url: custom, key: trigger.rawValue)
            return
        }

        // 2. Bundle sound file
        if let bundleURL = Bundle.main.url(forResource: trigger.rawValue, withExtension: "wav", subdirectory: "Sounds") {
            playFile(url: bundleURL, key: trigger.rawValue)
            return
        }

        // 3. macOS system sound
        if let sysName = systemSoundNames[trigger],
           let sound = NSSound(named: NSSound.Name(sysName)) {
            sound.volume = volume
            sound.play()
            return
        }

        // 4. Fallback beep
        NSSound.beep()
    }

    private func playFile(url: URL, key: String) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.play()
            players[key] = player
        } catch {
            print("[Argus] Play failed: \(error)")
        }
    }
}
