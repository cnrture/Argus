import AppKit
import AVFoundation
import Foundation

final class SoundManager {
    static let shared = SoundManager()
    private var players: [String: AVAudioPlayer] = [:]
    private var enabled = true
    private var volume: Float = 0.7

    func configure(enabled: Bool, volume: Float) {
        self.enabled = enabled
        self.volume = volume
    }

    func play(_ trigger: SoundTrigger, configs: [SoundEventConfig]) {
        guard enabled else { return }
        guard let config = configs.first(where: { $0.eventType == trigger }),
              config.enabled else { return }

        let url: URL
        if let custom = config.customSoundURL, FileManager.default.fileExists(atPath: custom.path) {
            url = custom
        } else if let bundleURL = Bundle.main.url(forResource: trigger.rawValue, withExtension: "wav", subdirectory: "Sounds") {
            url = bundleURL
        } else {
            // No sound file available — generate system sound
            NSSound.beep()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.play()
            players[trigger.rawValue] = player
        } catch {
            print("[SoundManager] Play failed: \(error)")
        }
    }
}
