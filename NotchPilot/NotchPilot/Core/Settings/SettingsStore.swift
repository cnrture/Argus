import SwiftUI
import Combine

enum BarWidth: String, CaseIterable, Codable {
    case narrow, normal, wide

    var displayName: String {
        switch self {
        case .narrow: "Dar"
        case .normal: "Normal"
        case .wide:   "Genis"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .narrow: 1.2
        case .normal: 1.5
        case .wide:   1.8
        }
    }
}

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
    var petStyle: PetStyle {
        didSet { UserDefaults.standard.set(petStyle.rawValue, forKey: "petStyle") }
    }
    var showBorder: Bool {
        didSet { UserDefaults.standard.set(showBorder, forKey: "showBorder") }
    }
    var idleOpacity: Double {
        didSet { UserDefaults.standard.set(idleOpacity, forKey: "idleOpacity") }
    }
    var barWidth: BarWidth {
        didSet { UserDefaults.standard.set(barWidth.rawValue, forKey: "barWidth") }
    }
    var barHeight: Double {
        didSet { UserDefaults.standard.set(barHeight, forKey: "barHeight") }
    }
    var cornerRadius: Double {
        didSet { UserDefaults.standard.set(cornerRadius, forKey: "cornerRadius") }
    }
    var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var barOffset: Double { // -1.0 (sol) to 1.0 (sag), 0 = orta
        didSet { UserDefaults.standard.set(barOffset, forKey: "barOffset") }
    }

    // Hooks — hangi ajanlar icin kur
    var enabledAgents: Set<String> {
        didSet { UserDefaults.standard.set(Array(enabledAgents), forKey: "enabledAgents") }
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

    // Monitor
    var selectedScreenName: String? {
        didSet { UserDefaults.standard.set(selectedScreenName, forKey: "selectedScreen") }
    }

    // Callback for when screen selection changes
    var onScreenChanged: (() -> Void)?

    var accentColor: Color {
        switch accentColorName {
        case "blue":   .blue
        case "purple": .purple
        case "green":  .green
        case "red":    .red
        case "pink":   .pink
        case "cyan":   .cyan
        default:       .orange
        }
    }

    init() {
        let defaults = UserDefaults.standard
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        showInFullscreen = defaults.object(forKey: "showInFullscreen") as? Bool ?? true
        nativeNotificationsEnabled = defaults.bool(forKey: "nativeNotifications")
        idleTimeout = defaults.object(forKey: "idleTimeout") as? TimeInterval ?? 900
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "system") ?? .system
        accentColorName = defaults.string(forKey: "accentColor") ?? "orange"
        petStyle = PetStyle(rawValue: defaults.string(forKey: "petStyle") ?? "dot") ?? .dot
        showBorder = defaults.object(forKey: "showBorder") as? Bool ?? true
        idleOpacity = defaults.object(forKey: "idleOpacity") as? Double ?? 0.45
        barWidth = BarWidth(rawValue: defaults.string(forKey: "barWidth") ?? "normal") ?? .normal
        barHeight = defaults.object(forKey: "barHeight") as? Double ?? 32
        cornerRadius = defaults.object(forKey: "cornerRadius") as? Double ?? 14
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 12
        barOffset = defaults.object(forKey: "barOffset") as? Double ?? 0
        if let agents = defaults.array(forKey: "enabledAgents") as? [String] {
            enabledAgents = Set(agents)
        } else {
            enabledAgents = Set(AgentSource.allCases.map(\.rawValue))
        }
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        soundVolume = defaults.object(forKey: "soundVolume") as? Float ?? 0.7
        autoSetupHooks = defaults.object(forKey: "autoSetupHooks") as? Bool ?? true
        selectedScreenName = defaults.string(forKey: "selectedScreen")

        if let data = defaults.data(forKey: "soundEvents"),
           let decoded = try? JSONDecoder().decode([SoundEventConfig].self, from: data) {
            soundEvents = decoded
        } else {
            soundEvents = SoundEventConfig.defaults
        }

        SoundManager.shared.configure(enabled: soundEnabled, volume: soundVolume)
    }
}
