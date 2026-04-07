import SwiftUI

enum AgentSource: String, Codable, CaseIterable, Equatable {
    case claude = "claude"
    case codex = "codex"
    case gemini = "gemini"
    case cursor = "cursor"
    case copilot = "copilot"
    case opencode = "opencode"
    case codebuddy = "codebuddy"
    case droid = "droid"
    case qoder = "qoder"
    case factory = "factory"

    var displayName: String {
        switch self {
        case .claude:    "Claude Code"
        case .codex:     "Codex"
        case .gemini:    "Gemini CLI"
        case .cursor:    "Cursor"
        case .copilot:   "Copilot"
        case .opencode:  "OpenCode"
        case .codebuddy: "CodeBuddy"
        case .droid:     "Droid"
        case .qoder:     "Qoder"
        case .factory:   "Factory"
        }
    }

    var icon: String {
        switch self {
        case .claude:    "c.circle.fill"
        case .codex:     "o.circle.fill"
        case .gemini:    "g.circle.fill"
        case .cursor:    "cursorarrow.rays"
        case .copilot:   "cp.circle.fill"
        case .opencode:  "chevron.left.forwardslash.chevron.right"
        case .codebuddy: "person.2.fill"
        case .droid:     "cpu"
        case .qoder:     "q.circle.fill"
        case .factory:   "hammer.fill"
        }
    }

    var color: Color {
        switch self {
        case .claude:    .orange
        case .codex:     .green
        case .gemini:    .blue
        case .cursor:    .purple
        case .copilot:   .cyan
        case .opencode:  .teal
        case .codebuddy: .pink
        case .droid:     .indigo
        case .qoder:     .mint
        case .factory:   .yellow
        }
    }

    var configPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .claude:    return home + "/.claude/settings.json"
        case .codex:     return home + "/.codex/hooks.json"
        case .gemini:    return home + "/.gemini/settings.json"
        case .cursor:    return home + "/.cursor/hooks.json"
        case .copilot:   return home + "/.copilot/hooks.json"
        case .opencode:  return home + "/.config/opencode/settings.json"
        case .codebuddy: return home + "/.codebuddy/settings.json"
        case .droid:     return home + "/.droid/settings.json"
        case .qoder:     return home + "/.qoder/settings.json"
        case .factory:   return home + "/.factory/settings.json"
        }
    }

    var hookFormat: HookFormat {
        switch self {
        case .claude, .qoder, .factory, .codebuddy:  .claude
        case .codex, .gemini, .copilot, .droid:       .nested
        case .cursor:                                  .flat
        case .opencode:                                .nested
        }
    }

    var eventMapping: [String: String] {
        switch self {
        case .claude, .qoder, .factory, .codebuddy:
            return [
                "session-start": "SessionStart",
                "session-end": "SessionEnd",
                "stop": "Stop",
                "pre-tool-use": "PreToolUse",
                "post-tool-use": "PostToolUse",
                "permission-request": "PermissionRequest",
                "notification": "Notification",
                "user-prompt-submit": "UserPromptSubmit",
                "pre-compact": "PreCompact",
                "subagent-stop": "SubagentStop",
            ]
        case .codex:
            return [
                "session-start": "SessionStart",
                "stop": "Stop",
                "pre-tool-use": "PreToolUse",
                "post-tool-use": "PostToolUse",
                "user-prompt-submit": "UserPromptSubmit",
            ]
        case .gemini:
            return [
                "session-start": "SessionStart",
                "session-end": "SessionEnd",
                "pre-tool-use": "BeforeTool",
                "post-tool-use": "AfterTool",
                "stop": "AfterAgent",
                "user-prompt-submit": "BeforeAgent",
                "pre-compact": "PreCompress",
                "notification": "Notification",
            ]
        case .cursor:
            return [
                "user-prompt-submit": "beforeSubmitPrompt",
                "pre-tool-use": "beforeShellExecution",
                "post-tool-use": "afterShellExecution",
                "stop": "stop",
                "permission-request": "beforeShellExecution",
            ]
        case .copilot, .droid, .opencode:
            return [
                "session-start": "SessionStart",
                "session-end": "SessionEnd",
                "stop": "Stop",
                "pre-tool-use": "PreToolUse",
                "post-tool-use": "PostToolUse",
                "user-prompt-submit": "UserPromptSubmit",
            ]
        }
    }

    var timeoutMultiplier: Int {
        self == .gemini ? 1000 : 1
    }
}

enum HookFormat {
    case claude
    case nested
    case flat
}
