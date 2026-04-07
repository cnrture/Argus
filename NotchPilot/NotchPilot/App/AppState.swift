import SwiftUI

enum NotchPanelState: Equatable {
    case hidden
    case compact
    case expanded
}

@Observable
final class AppState {
    var panelState: NotchPanelState = .hidden
    var sessions: [String: SessionInfo] = [:]
    var activeSessionId: String?
    var isHovered: Bool = false
    var isExpanded: Bool = false
    var isFullscreen: Bool = false
    var isBootAnimating: Bool = false

    var hasActiveSessions: Bool {
        !sessions.isEmpty
    }

    var activeSession: SessionInfo? {
        guard let id = activeSessionId else { return nil }
        return sessions[id]
    }

    var sortedSessions: [SessionInfo] {
        sessions.values.sorted { a, b in
            if a.isIdle != b.isIdle { return !a.isIdle }
            return a.lastActivity > b.lastActivity
        }
    }

    // Permission/Question/Plan events for active session (set by SessionStore)
    var activePermission: PermissionEvent?
    var activeQuestion: QuestionEvent?
    var activePlan: PlanEvent?
}

/// Lightweight snapshot of Session for UI binding
struct SessionInfo: Identifiable, Equatable {
    let id: String
    var title: String
    var source: AgentSource
    var status: SessionStatus
    let startTime: Date
    var lastActivity: Date
    var lastToolName: String?
    var lastStatusText: String?
    var isIdle: Bool
    var pendingPermission: Bool
    var pendingQuestion: Bool
    var pendingPlan: Bool

    init(id: String, title: String, source: AgentSource = .claude,
         status: SessionStatus = .idle,
         startTime: Date = Date(), lastActivity: Date = Date(),
         lastToolName: String? = nil, lastStatusText: String? = nil,
         isIdle: Bool = false,
         pendingPermission: Bool = false, pendingQuestion: Bool = false,
         pendingPlan: Bool = false) {
        self.id = id
        self.title = title
        self.source = source
        self.status = status
        self.startTime = startTime
        self.lastActivity = lastActivity
        self.lastToolName = lastToolName
        self.lastStatusText = lastStatusText
        self.isIdle = isIdle
        self.pendingPermission = pendingPermission
        self.pendingQuestion = pendingQuestion
        self.pendingPlan = pendingPlan
    }
}
