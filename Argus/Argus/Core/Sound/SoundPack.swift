import Foundation

enum SoundTrigger: String, CaseIterable, Codable {
    case sessionStarted = "session-started"
    case sessionEnded = "session-ended"
    case permissionNeeded = "permission-needed"
    case questionAsked = "question-asked"
    case planReady = "plan-ready"
    case taskCompleted = "task-completed"
    case error = "error"
    case idle = "idle"

    var displayName: String {
        switch self {
        case .sessionStarted:   L10n["sound.sessionStarted"]
        case .sessionEnded:     L10n["sound.sessionEnded"]
        case .permissionNeeded: L10n["sound.permissionNeeded"]
        case .questionAsked:    L10n["sound.questionAsked"]
        case .planReady:        L10n["sound.planReady"]
        case .taskCompleted:    L10n["sound.taskCompleted"]
        case .error:            L10n["sound.error"]
        case .idle:             L10n["sound.idle"]
        }
    }

    var defaultFileName: String {
        rawValue + ".wav"
    }
}

struct SoundEventConfig: Identifiable, Codable {
    let id: String
    let eventType: SoundTrigger
    var enabled: Bool
    var customSoundURL: URL?

    static var defaults: [SoundEventConfig] {
        SoundTrigger.allCases.map { trigger in
            SoundEventConfig(
                id: trigger.rawValue,
                eventType: trigger,
                enabled: trigger != .idle,
                customSoundURL: nil
            )
        }
    }
}
