import SwiftUI
import AppKit

enum WelcomePhase: Equatable {
    case idle
    case emerge
    case gather
    case morph
    case reveal
    case steps
    case done
}

@Observable
final class WelcomeFlowState {
    var phase: WelcomePhase = .idle
    var currentStep: Int = 0
    var isActive: Bool { phase != .idle && phase != .done }

    static let hasSeenKey = "hasSeenWelcomeAnimation"

    static var shouldRunOnLaunch: Bool {
        !UserDefaults.standard.bool(forKey: hasSeenKey)
    }

    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Phase durations tuned per user's motion preference.
    var emergeDuration: TimeInterval { Self.reduceMotion ? 0.4 : 1.2 }
    var gatherDuration: TimeInterval { Self.reduceMotion ? 0.3 : 1.0 }

    func markComplete() {
        phase = .done
        UserDefaults.standard.set(true, forKey: Self.hasSeenKey)
    }

    func skip() {
        markComplete()
    }
}
