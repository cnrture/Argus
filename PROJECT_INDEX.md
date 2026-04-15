# Project Index: Argus

Generated: 2026-04-15

Native macOS app that turns the MacBook notch into a real-time control panel for AI coding agents (Claude Code, Codex, Gemini CLI, Cursor, Copilot, OpenCode, CodeBuddy, Droid, Qoder, Factory). Free, open-source alternative to Vibe Island.

## Project Structure

```
Argus/
├── Argus.xcodeproj/              # Xcode project (schemes: Argus, argus-bridge)
├── Argus/                        # Main app target (SwiftUI/AppKit)
│   ├── App/                      # Entry + app-level state
│   ├── Models/                   # Session, HookEvent, Permission/Question/Plan events, AgentSource, DiffPreview
│   ├── Core/
│   │   ├── Socket/               # SocketServer (AF_UNIX), JSONLParser
│   │   ├── Session/              # SessionStore, SessionScanner, SessionTitleResolver, ToolUseIdCache
│   │   ├── Hooks/                # HookInstaller, HookConfigMerger
│   │   ├── Events/               # EventMonitor(s)
│   │   ├── Screen/               # NotchDetector, ScreenObserver, ScreenSelector
│   │   ├── Sound/                # SoundManager, SoundPack (8-bit)
│   │   ├── Voice/                # VoiceCommandManager
│   │   ├── Jump/                 # WindowJumper, SmartSuppress
│   │   └── Settings/             # SettingsStore, L10n, UpdateManager (Sparkle)
│   ├── UI/
│   │   ├── Notch/                # NotchWindow(Controller), Compact/Expanded views, Permission/Question/Plan/Error/Completion/IdlePrompt
│   │   ├── MenuBar/              # MenuBarView
│   │   ├── Settings/             # SettingsView
│   │   ├── Onboarding/           # OnboardingView
│   │   ├── Pet/                  # DeskPet, SpriteSheetAnimator
│   │   └── Shared/               # StatusDot, StatusPet, GlowEffect, MarkdownText, SessionCard
│   ├── Resources/                # Localizable.strings (tr, en, ko, pt-BR, de, es, fr, ja, zh-Hans)
│   ├── Assets.xcassets/          # AppIcon, AccentColor
│   └── Info.plist
├── argus-bridge/                 # Standalone CLI (zero deps)
│   ├── main.swift                # Entry: argus-bridge <event-type> [--source] [--session-id]
│   ├── SocketClient.swift        # Writes JSONL to ~/.argus/argus.sock
│   └── EventRouter.swift
└── ExportOptions.plist
Casks/argus.rb                    # Homebrew cask
scripts/                          # release.sh, update-appcast.sh, setup-sparkle-tools.sh, backup-sparkle-key.sh
.github/workflows/release.yml     # Release pipeline
Makefile                          # build, bridge, archive, dmg, clean, release
```

## Entry Points

- **App**: `Argus/Argus/App/ArgusApp.swift` → `AppDelegate` (bootstraps window, socket, hooks, session scan, desk pet, voice)
- **CLI bridge**: `Argus/argus-bridge/main.swift` (stdin JSON → Unix socket `~/.argus/argus.sock`)
- **UI root**: `NotchWindowController` → `NotchContainerView` (Compact ↔ Expanded)

## Core Modules

### App (`Argus/App/`)
- `AppDelegate.swift` — lifecycle bootstrap, 5-min hook repair timer, existing-session scan
- `ArgusApp.swift` — `@main` SwiftUI App
- `AppState.swift` — `@Observable` bridge between business logic and views

### Models (`Argus/Models/`)
- `Session.swift` — session lifecycle (`idle → working → waiting → idle`)
- `HookEvent.swift` — pointer (actual types live in `SocketServer.swift`)
- `AgentSource.swift` — 10 agent enum (claude, codex, gemini, cursor, copilot, opencode, codebuddy, droid, qoder, factory) with config paths, event mappings, hook formats
- `PermissionEvent`, `QuestionEvent`, `PlanEvent`, `DiffPreview`

### Core
- **Socket**: `SocketServer` (AF_UNIX SOCK_STREAM, keeps connection open for blocking events), `JSONLParser`
- **Session**: `SessionStore` (event processing + state machine), `SessionScanner` (existing PID discovery), `SessionTitleResolver`, `ToolUseIdCache`
- **Hooks**: `HookInstaller` (install/uninstall/verify/repair), `HookConfigMerger` (3 formats: `.claude`, `.nested`, `.flat`; backs up with `.argus-backup` suffix)
- **Screen**: `NotchDetector`, `ScreenObserver`, `ScreenSelector`
- **Jump**: `WindowJumper` (jump to owning terminal/IDE), `SmartSuppress` (prevents redundant sounds)
- **Settings**: `SettingsStore` (UserDefaults + `didSet`), `L10n` (runtime language switch), `UpdateManager` (Sparkle)

### UI — Notch
- `NotchWindow` (transparent NSPanel at top of screen), `PassThroughHostingView` (pass-through mouse except hit-test rect)
- Panel states: `hidden → compact → expanded`; fullscreen 5pt hover trigger
- Views: `CompactView`, `ExpandedOverviewView`, `PermissionView`, `QuestionView`, `PlanReviewView`, `CompletionCardView`, `ErrorCardView`, `IdlePromptView`, `DiffPreviewView`, `NotchShape`

## Data Flow

```
AI Agent Hook → argus-bridge (CLI) → Unix Socket (~/.argus/argus.sock, chmod 600)
              → SocketServer → JSONLParser → HookEvent
              → SessionStore (state machine) → AppState → SwiftUI views
For blocking events (permission): socket stays open until user responds via UI.
```

## Build & Commands (Makefile)

- `make build` — Debug build (xcodebuild, scheme `Argus`)
- `make bridge` — Release build of CLI (scheme `argus-bridge`)
- `make archive` — Release archive (manual signing, Developer ID, team `39Z244SGXG`)
- `make export` — Copy app out of archive
- `make sign` / `make notarize` — Codesign + notarytool + stapler
- `make dmg` — `hdiutil create` UDZO DMG
- `make release` — `scripts/release.sh`
- `make clean` — `xcodebuild clean` + `rm -rf build/ release/`

## Dependencies (SPM)

- `KeyboardShortcuts` (sindresorhus) — Cmd+Y/N (permissions), Cmd+1/2/3 (questions)
- `LaunchAtLogin-Modern` (sindresorhus)
- `Sparkle` — auto-update

## Configuration

- `Argus/Info.plist` — app metadata
- `Argus/ExportOptions.plist` — archive export
- `Casks/argus.rb` — Homebrew cask
- `.github/workflows/release.yml` — release pipeline

## Localization

`Resources/*.lproj/Localizable.strings` + `L10n.swift` helper. Languages: tr, en, ko, pt-BR, de, es, fr, ja, zh-Hans.

## Key Patterns

- No visible windows, no dock icon, no standard menu bar — lives entirely in notch panel
- `@Observable` (Swift Observation), not `ObservableObject`/Combine
- `SettingsStore` persists via `UserDefaults` with `didSet`
- 5-second timer cleans up sessions whose PIDs have exited
- Hook configs backed up before first modification; merger never touches existing hooks

## Requirements

- macOS 15.0 (Sequoia)+
- Xcode with Swift 6 toolchain
- Apple Silicon or Intel

## Quick Start

1. `make build` — debug build
2. Run from Xcode or `open build/...` — approves hook install on first launch
3. Invoke an AI agent (e.g. Claude Code); events appear in the notch panel
