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
        case .sessionStarted:   "Oturum Başladı"
        case .sessionEnded:     "Oturum Bitti"
        case .permissionNeeded: "İzin Bekliyor"
        case .questionAsked:    "Soru Soruldu"
        case .planReady:        "Plan Hazır"
        case .taskCompleted:    "Görev Tamamlandı"
        case .error:            "Hata Oluştu"
        case .idle:             "Hareketsiz"
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
