import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Codable {
    case dark, light, system

    var displayName: String {
        switch self {
        case .dark:   "Dark"
        case .light:  "Light"
        case .system: "System"
        }
    }
}

@Observable
final class SettingsStore {
    // General
    var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
    }
    var showInFullscreen: Bool {
        didSet { UserDefaults.standard.set(showInFullscreen, forKey: "showInFullscreen") }
    }
    var nativeNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(nativeNotificationsEnabled, forKey: "nativeNotifications") }
    }
    var idleTimeout: TimeInterval {
        didSet { UserDefaults.standard.set(idleTimeout, forKey: "idleTimeout") }
    }

    // Appearance
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    var accentColorName: String {
        didSet { UserDefaults.standard.set(accentColorName, forKey: "accentColor") }
    }

    // Sound
    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
            SoundManager.shared.configure(enabled: soundEnabled, volume: soundVolume)
        }
    }
    var soundVolume: Float {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
            SoundManager.shared.configure(enabled: soundEnabled, volume: soundVolume)
        }
    }
    var soundEvents: [SoundEventConfig] {
        didSet {
            if let data = try? JSONEncoder().encode(soundEvents) {
                UserDefaults.standard.set(data, forKey: "soundEvents")
            }
        }
    }

    // Hooks
    var autoSetupHooks: Bool {
        didSet { UserDefaults.standard.set(autoSetupHooks, forKey: "autoSetupHooks") }
    }

    init() {
        let defaults = UserDefaults.standard
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        showInFullscreen = defaults.object(forKey: "showInFullscreen") as? Bool ?? true
        nativeNotificationsEnabled = defaults.bool(forKey: "nativeNotifications")
        idleTimeout = defaults.object(forKey: "idleTimeout") as? TimeInterval ?? 900
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "system") ?? .system
        accentColorName = defaults.string(forKey: "accentColor") ?? "orange"
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        soundVolume = defaults.object(forKey: "soundVolume") as? Float ?? 0.7
        autoSetupHooks = defaults.object(forKey: "autoSetupHooks") as? Bool ?? true

        if let data = defaults.data(forKey: "soundEvents"),
           let decoded = try? JSONDecoder().decode([SoundEventConfig].self, from: data) {
            soundEvents = decoded
        } else {
            soundEvents = SoundEventConfig.defaults
        }

        SoundManager.shared.configure(enabled: soundEnabled, volume: soundVolume)
    }
}
