import Foundation

@Observable
final class Session: Identifiable, Equatable {
    let id: String
    let startTime: Date
    var title: String
    var source: AgentSource
    var status: SessionStatus
    var lastActivity: Date
    var lastToolName: String?
    var lastStatusText: String?
    var pendingPermission: PermissionEvent?
    var pendingQuestion: QuestionEvent?
    var pendingPlan: PlanEvent?
    var autoApproveRules: Set<String> = []

    static let idleTimeout: TimeInterval = 900

    var isIdle: Bool {
        status == .idle && Date().timeIntervalSince(lastActivity) > Self.idleTimeout
    }

    init(id: String, title: String, source: AgentSource = .claude) {
        self.id = id
        self.startTime = Date()
        self.title = title
        self.source = source
        self.status = .idle
        self.lastActivity = Date()
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

enum SessionStatus: String, Codable, Equatable {
    case working
    case idle
    case waiting
    case compacting
    case error
    case ended

    func canTransition(to next: SessionStatus) -> Bool {
        switch (self, next) {
        case (.idle, .working), (.idle, .waiting), (.idle, .ended):       return true
        case (.working, .idle), (.working, .waiting), (.working, .error): return true
        case (.waiting, .working), (.waiting, .idle):                     return true
        case (.compacting, .idle), (.compacting, .working):               return true
        case (_, .ended):                                                  return true
        default:                                                           return false
        }
    }
}
