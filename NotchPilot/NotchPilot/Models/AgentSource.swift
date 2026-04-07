import SwiftUI

enum AgentSource: String, Codable, CaseIterable, Equatable {
    case claude = "claude"
    case codex = "codex"
    case gemini = "gemini"
    case cursor = "cursor"

    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex:  "Codex"
        case .gemini: "Gemini CLI"
        case .cursor: "Cursor"
        }
    }

    var icon: String {
        switch self {
        case .claude: "c.circle.fill"
        case .codex:  "o.circle.fill"
        case .gemini: "g.circle.fill"
        case .cursor: "cursorarrow.rays"
        }
    }

    var color: Color {
        switch self {
        case .claude: .orange
        case .codex:  .green
        case .gemini: .blue
        case .cursor: .purple
        }
    }

    var configPath: String {
        let home = NSHomeDirectory()
        switch self {
        case .claude: return home + "/.claude/settings.json"
        case .codex:  return home + "/.codex/hooks.json"
        case .gemini: return home + "/.gemini/settings.json"
        case .cursor: return home + "/.cursor/hooks.json"
        }
    }

    var hookFormat: HookFormat {
        switch self {
        case .claude:           .claude
        case .codex, .gemini:   .nested
        case .cursor:           .flat
        }
    }

    /// Event isimlerini her CLI'nın formatına çevir
    var eventMapping: [String: String] {
        switch self {
        case .claude:
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
        }
    }

    /// Gemini timeout ms cinsinden, diğerleri saniye
    var timeoutMultiplier: Int {
        self == .gemini ? 1000 : 1
    }
}

enum HookFormat {
    case claude  // {matcher, hooks: [{type, command, timeout}]}
    case nested  // {hooks: [{type, command, timeout}]}
    case flat    // {command: "..."}
}
