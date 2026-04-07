import Foundation
import Combine

final class SessionStore {
    private(set) var sessions: [String: Session] = [:]
    private let toolUseIdCache = ToolUseIdCache()
    private var pendingResponders: [String: (SocketResponse) -> Void] = [:]

    var sessionsArray: [Session] {
        sessions.values.sorted { a, b in
            if a.isIdle != b.isIdle { return !a.isIdle }
            return a.lastActivity > b.lastActivity
        }
    }

    var activeSessions: [Session] {
        sessions.values.filter { $0.status != .ended }
    }

    func addDiscoveredSession(_ session: Session) {
        sessions[session.id] = session
    }

    func removeSession(id: String) {
        sessions.removeValue(forKey: id)
    }

    // MARK: - Event Processing

    func process(event: HookEvent, appState: AppState, respond: @escaping (SocketResponse) -> Void) {
        // Session yoksa otomatik oluştur (app açıkken başlamış session'lar için)
        if event.event != .sessionStart && event.event != .notification && sessions[event.sessionId] == nil {
            let title = SessionTitleResolver.resolve(cwd: event.cwd)
            let session = Session(id: event.sessionId, title: title, source: event.agentSource)
            sessions[event.sessionId] = session
            appState.activeSessionId = event.sessionId
            appState.panelState = .compact
        }

        switch event.event {
        case .sessionStart:
            handleSessionStart(event: event, appState: appState)

        case .sessionEnd:
            handleSessionEnd(event: event, appState: appState)

        case .stop:
            handleStop(event: event, appState: appState)

        case .preToolUse:
            handlePreToolUse(event: event, appState: appState)

        case .postToolUse:
            handlePostToolUse(event: event, appState: appState)

        case .permissionRequest:
            handlePermissionRequest(event: event, appState: appState, respond: respond)

        case .notification:
            break

        case .userPromptSubmit:
            handleUserPromptSubmit(event: event, appState: appState)

        case .preCompact:
            handlePreCompact(event: event, appState: appState)

        case .subagentStop:
            handleSubagentStop(event: event, appState: appState)
        }

        syncToAppState(appState)
    }

    // MARK: - Event Handlers

    private func handleSessionStart(event: HookEvent, appState: AppState) {
        let title = SessionTitleResolver.resolve(cwd: event.cwd)
        let session = Session(id: event.sessionId, title: title, source: event.agentSource)
        session.cwd = event.cwd
        WindowJumper.detectOwnerApp(for: session)

        // Replace any discovered "existing-" session with the same cwd
        let existingKeys = sessions.keys.filter { $0.hasPrefix("existing-") }
        for key in existingKeys {
            if let existing = sessions[key], existing.title == title {
                sessions.removeValue(forKey: key)
                if appState.activeSessionId == key {
                    appState.activeSessionId = event.sessionId
                }
            }
        }

        sessions[event.sessionId] = session

        if appState.activeSessionId == nil {
            appState.activeSessionId = event.sessionId
        }
        appState.panelState = .compact
    }

    private func handleSessionEnd(event: HookEvent, appState: AppState) {
        toolUseIdCache.clearSession(event.sessionId)

        // Clear pending responders for this session
        for (key, _) in pendingResponders {
            pendingResponders.removeValue(forKey: key)
        }

        // Clear pending events
        sessions[event.sessionId]?.pendingPermission = nil
        sessions[event.sessionId]?.pendingQuestion = nil
        sessions[event.sessionId]?.pendingPlan = nil

        sessions.removeValue(forKey: event.sessionId)

        if appState.activeSessionId == event.sessionId {
            appState.activeSessionId = sessions.keys.first
        }
        if sessions.isEmpty {
            appState.panelState = .hidden
        }
    }

    private func handleStop(event: HookEvent, appState: AppState) {
        transition(sessionId: event.sessionId, to: .idle)
        sessions[event.sessionId]?.lastActivity = Date()

        // Claude'un son yanıtını kaydet
        if let lastMsg = event.data?.lastAssistantMessage, !lastMsg.isEmpty {
            let clean = lastMsg.trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = clean.count > 60 ? String(clean.prefix(60)) + "..." : clean
            sessions[event.sessionId]?.lastStatusText = truncated
        }
    }

    private func handlePreToolUse(event: HookEvent, appState: AppState) {
        transition(sessionId: event.sessionId, to: .working)
        sessions[event.sessionId]?.lastActivity = Date()

        if let toolName = event.data?.toolName {
            sessions[event.sessionId]?.lastToolName = toolName
        }

        // Cache tool_use_id for PermissionRequest correlation
        if let toolName = event.data?.toolName,
           let toolUseId = event.data?.toolUseId {
            let inputStr = serializeToolInput(event.data?.toolInput)
            toolUseIdCache.store(
                sessionId: event.sessionId,
                toolName: toolName,
                toolInput: inputStr,
                toolUseId: toolUseId
            )
        }
    }

    private func handlePostToolUse(event: HookEvent, appState: AppState) {
        sessions[event.sessionId]?.lastActivity = Date()

        // Cancel pending permission if tool was already executed (terminal approval)
        if sessions[event.sessionId]?.pendingPermission != nil {
            sessions[event.sessionId]?.pendingPermission = nil
            transition(sessionId: event.sessionId, to: .working)
        }
    }

    private func handlePermissionRequest(event: HookEvent, appState: AppState, respond: @escaping (SocketResponse) -> Void) {
        guard let toolName = event.data?.toolName else { return }

        // Check auto-approve rules
        if let session = sessions[event.sessionId],
           session.autoApproveRules.contains(toolName) {
            let response = SocketResponse(
                id: event.id,
                response: ResponsePayload(
                    hookSpecificOutput: HookSpecificOutput(
                        hookEventName: "PermissionRequest",
                        decision: PermissionDecision(behavior: "allow", reason: nil),
                        selectedOption: nil
                    )
                )
            )
            respond(response)
            return
        }

        transition(sessionId: event.sessionId, to: .waiting)
        appState.activeSessionId = event.sessionId

        // Resolve tool_use_id from cache
        let inputStr = serializeToolInput(event.data?.toolInput)
        let toolUseId = toolUseIdCache.retrieve(
            sessionId: event.sessionId,
            toolName: toolName,
            toolInput: inputStr
        ) ?? event.data?.toolUseId ?? event.id

        let permissionEvent = PermissionEvent(
            id: event.id,
            toolName: toolName,
            toolInput: event.data?.toolInput,
            toolUseId: toolUseId,
            receivedAt: Date()
        )

        sessions[event.sessionId]?.pendingPermission = permissionEvent
        pendingResponders[event.id] = respond
    }

    private func handleUserPromptSubmit(event: HookEvent, appState: AppState) {
        transition(sessionId: event.sessionId, to: .working)
        sessions[event.sessionId]?.lastActivity = Date()

        // Son prompt'u yakala
        let prompt = event.data?.prompt
            ?? event.data?.message
            ?? event.data?.content

        if let prompt, !prompt.isEmpty {
            let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated = clean.count > 60 ? String(clean.prefix(60)) + "..." : clean
            sessions[event.sessionId]?.lastStatusText = truncated
        }
    }

    private func handlePreCompact(event: HookEvent, appState: AppState) {
        transition(sessionId: event.sessionId, to: .compacting)
    }

    private func handleSubagentStop(event: HookEvent, appState: AppState) {
        sessions[event.sessionId]?.lastActivity = Date()
    }

    // MARK: - State Transition

    private func transition(sessionId: String, to newStatus: SessionStatus) {
        guard let session = sessions[sessionId] else { return }
        if session.status.canTransition(to: newStatus) {
            session.status = newStatus
        }
    }

    // MARK: - Response

    func respondToPermission(eventId: String, allow: Bool, session: Session?) {
        let decision = PermissionDecision(
            behavior: allow ? "allow" : "deny",
            reason: allow ? nil : "Kullanıcı tarafından reddedildi"
        )

        let response = SocketResponse(
            id: eventId,
            response: ResponsePayload(
                hookSpecificOutput: HookSpecificOutput(
                    hookEventName: "PermissionRequest",
                    decision: decision,
                    selectedOption: nil
                )
            )
        )

        pendingResponders[eventId]?(response)
        pendingResponders.removeValue(forKey: eventId)

        // Clear pending permission
        session?.pendingPermission = nil
        if let session {
            transition(sessionId: session.id, to: .working)
        }
    }

    func respondToQuestion(eventId: String, answer: String) {
        let response = SocketResponse(
            id: eventId,
            response: ResponsePayload(
                hookSpecificOutput: HookSpecificOutput(
                    hookEventName: "Elicitation",
                    decision: nil,
                    selectedOption: answer
                )
            )
        )

        pendingResponders[eventId]?(response)
        pendingResponders.removeValue(forKey: eventId)
    }

    // MARK: - Sync

    private func syncToAppState(_ appState: AppState) {
        appState.sessions = sessions.mapValues { session in
            SessionInfo(
                id: session.id,
                title: session.title,
                source: session.source,
                status: session.status,
                startTime: session.startTime,
                lastActivity: session.lastActivity,
                lastToolName: session.lastToolName,
                lastStatusText: session.lastStatusText,
                isIdle: session.isIdle,
                pendingPermission: session.pendingPermission != nil,
                pendingQuestion: session.pendingQuestion != nil,
                pendingPlan: session.pendingPlan != nil
            )
        }

        // Sync active session's pending events
        if let activeId = appState.activeSessionId,
           let session = sessions[activeId] {
            appState.activePermission = session.pendingPermission
            appState.activeQuestion = session.pendingQuestion
            appState.activePlan = session.pendingPlan
        } else {
            appState.activePermission = nil
            appState.activeQuestion = nil
            appState.activePlan = nil
        }
    }

    func addAutoApproveRule(sessionId: String, toolName: String) {
        sessions[sessionId]?.autoApproveRules.insert(toolName)
    }

    // MARK: - Helpers

    private func serializeToolInput(_ input: [String: AnyCodableValue]?) -> String {
        guard let input else { return "" }
        let sorted = input.sorted { $0.key < $1.key }
        return sorted.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }
}
