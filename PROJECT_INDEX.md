# Project Index: Argus

Generated: 2026-04-07

## Project Structure

```
Argus/
├── Makefile                          # Build automation (xcodebuild)
├── Casks/argus.rb              # Homebrew Cask formula
├── Argus/
│   ├── Argus.xcodeproj/        # Xcode project (2 schemes)
│   ├── ExportOptions.plist          # Archive export config
│   ├── Argus/                  # Main app target
│   │   ├── App/                     # App entry, delegate, state
│   │   ├── Core/                    # Business logic
│   │   │   ├── Events/             # Mouse/keyboard event monitors
│   │   │   ├── Hooks/              # Hook install/merge/repair
│   │   │   ├── Jump/               # Window focus & smart suppress
│   │   │   ├── Screen/             # Notch detection, screen selection
│   │   │   ├── Session/            # Session lifecycle & scanning
│   │   │   ├── Settings/           # SettingsStore, L10n, UpdateManager
│   │   │   ├── Socket/             # Unix socket server, JSONL parser
│   │   │   ├── Sound/              # Sound manager & triggers
│   │   │   └── Voice/              # Speech recognition commands
│   │   ├── Models/                  # Data types (Session, HookEvent, AgentSource, etc.)
│   │   ├── UI/                      # SwiftUI views
│   │   │   ├── Notch/              # Compact bar, expanded panel, permission/question/plan views
│   │   │   ├── MenuBar/           # Menu bar extra view
│   │   │   ├── Onboarding/        # First-launch onboarding
│   │   │   ├── Pet/               # Desk pet (cat/dog sprite animation)
│   │   │   ├── Settings/          # Settings window
│   │   │   └── Shared/            # Reusable components (StatusDot, GlowEffect, MarkdownText)
│   │   ├── Resources/              # Localizable.strings (9 langs), pet sprites
│   │   └── Assets.xcassets/        # App icon, accent color
│   └── argus-bridge/          # CLI bridge target (3 files)
│       ├── main.swift              # Entry point — reads stdin, sends to socket
│       ├── EventRouter.swift       # Builds message JSON, determines blocking events
│       └── SocketClient.swift      # Unix socket client connection
```

## Entry Points

- **App**: `Argus/App/ArgusApp.swift` — `@main` SwiftUI app, delegates to `AppDelegate`
- **CLI Bridge**: `argus-bridge/main.swift` — `argus-bridge <event-type> [--source <agent>] [--session-id <id>]`
- **Bootstrap**: `App/AppDelegate.swift` — Creates window, starts socket server, installs hooks, scans sessions

## Core Modules

### Socket Communication
- `Core/Socket/SocketServer.swift` — AF_UNIX listener at `~/.argus/argus.sock`, GCD-based accept/read
- `Core/Socket/JSONLParser.swift` — Parses newline-delimited JSON messages into typed events
- Event protocol: Bridge sends `HookEvent` JSON → Server parses → `SessionStore.process()` → UI update or blocking response

### Session Management
- `Core/Session/SessionStore.swift` — Central event processor, state machine (`idle↔working↔waiting↔error↔ended`), permission/question response handling
- `Core/Session/SessionScanner.swift` — Discovers running `claude` processes via `pgrep`, resolves CWD via `lsof`
- `Core/Session/SessionTitleResolver.swift` — Generates session titles from CWD path
- `Core/Session/ToolUseIdCache.swift` — Correlates `PreToolUse` events with `PermissionRequest` via tool_use_id

### Hook System
- `Core/Hooks/HookInstaller.swift` — Install/uninstall/verify-repair per agent, bridge binary deployment to `~/.argus/bin/`
- `Core/Hooks/HookConfigMerger.swift` — Non-destructive JSON merge supporting 3 formats: `.claude`, `.nested`, `.flat`

### Multi-Agent
- `Models/AgentSource.swift` — 10 agents: Claude, Codex, Gemini, Cursor, Copilot, OpenCode, CodeBuddy, Droid, Qoder, Factory
- Each defines: `configPath`, `hookFormat`, `eventMapping` (internal→native event names), `timeoutMultiplier`

### Window & UI
- `UI/Notch/NotchWindowController.swift` — Transparent NSPanel, hover detection, expand/collapse, fullscreen support, keyboard shortcuts
- `UI/Notch/NotchContainerView.swift` — Root SwiftUI view composing compact bar and expanded panel
- `UI/Notch/PassThroughHostingView.swift` — NSHostingView subclass with configurable hit-test rect
- `Core/Screen/NotchDetector.swift` — `NSScreen` extension for physical notch detection via `safeAreaInsets`

### Platform Features
- `Core/Sound/SoundManager.swift` — Singleton, priority: custom file → bundle .wav → macOS system sound → beep
- `Core/Voice/VoiceCommandManager.swift` — On-device `SFSpeechRecognizer` (tr-TR/en-US), recognizes "izin ver"/"allow"/"deny"/"reddet"
- `Core/Jump/WindowJumper.swift` — PID→parent chain traversal to find owning .app bundle, activates terminal/IDE
- `Core/Jump/SmartSuppress.swift` — Suppresses notifications when frontmost app matches session owner
- `Core/Settings/UpdateManager.swift` — Sparkle auto-update integration

## Key Data Types

| Type | File | Purpose |
|------|------|---------|
| `HookEvent` | Socket/SocketServer.swift | Inbound event from bridge (16 event types) |
| `HookEventType` | Socket/SocketServer.swift | Enum: session-start, permission-request, stop, pre-tool-use, etc. |
| `Session` | Models/Session.swift | Runtime session with status FSM, pending events, auto-approve rules |
| `SessionInfo` | App/AppState.swift | Lightweight UI-bindable snapshot of Session |
| `AppState` | App/AppState.swift | `@Observable` root state: panel state, sessions, active events |
| `AgentSource` | Models/AgentSource.swift | Enum of 10 supported AI agents with config metadata |
| `PermissionEvent` | Models/PermissionEvent.swift | Pending permission with tool name, input, tool_use_id |
| `QuestionEvent` | Models/QuestionEvent.swift | Multiple-choice or free-text question from agent |
| `PlanEvent` | Models/PlanEvent.swift | Plan review with markdown content |
| `SocketResponse` | Socket/SocketServer.swift | Outbound response (permission decision or question answer) |

## Configuration

| File | Purpose |
|------|---------|
| `Makefile` | Build/archive/sign/notarize/DMG commands |
| `Info.plist` | Microphone/speech permissions, Sparkle feed URL |
| `Argus.entitlements` | App sandbox disabled (needs filesystem + process access) |
| `ExportOptions.plist` | Xcode archive export configuration |
| `Casks/argus.rb` | Homebrew Cask formula |

## Dependencies (SPM)

| Package | Version | Purpose |
|---------|---------|---------|
| KeyboardShortcuts | 2.4.0 | Global hotkeys (Cmd+Y/N, Cmd+1/2/3, Cmd+Shift+P) |
| LaunchAtLogin-Modern | 1.1.0 | Login item registration |
| Sparkle | 2.9.1 | Auto-update framework |

## Localization

9 languages via `Localizable.strings`: tr, en, ko, pt-BR, de, es, fr, ja, zh-Hans.
Runtime switching via `L10n` subscript helper — reads from language-specific bundle.

## Runtime Paths

| Path | Purpose |
|------|---------|
| `~/.argus/argus.sock` | Unix socket (chmod 600) |
| `~/.argus/bin/argus-bridge` | Bridge binary (chmod 755) |
| `~/.claude/settings.json` | Claude Code hook config |
| `~/.codex/hooks.json` | Codex hook config |
| `~/.gemini/settings.json` | Gemini CLI hook config |
| `~/.cursor/hooks.json` | Cursor hook config |

## Build & Run

```bash
make build          # Debug build
make bridge         # Build CLI bridge (Release)
make clean          # Clean all artifacts
make archive        # Release archive
make dmg            # Create distributable DMG
```

Requirements: macOS 15.0+, Xcode with Swift 6 toolchain.
