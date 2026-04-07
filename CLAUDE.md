# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Argus is a native macOS app that turns the MacBook notch into a real-time control panel for AI coding agents. It's a free, open-source alternative to Vibe Island. The app communicates with AI agents (Claude Code, Codex, Gemini CLI, Cursor, etc.) via a hook-based architecture using Unix sockets.

## Build Commands

```bash
make build       # Debug build (xcodebuild)
make bridge      # Build the argus-bridge CLI binary (Release)
make clean       # Clean build artifacts
make archive     # Release archive
make dmg         # Build DMG installer (runs archive + export)
```

The Xcode project is at `Argus/Argus.xcodeproj` with two schemes: `Argus` (main app) and `argus-bridge` (CLI tool).

## Architecture

```
AI Agent Hook → argus-bridge (CLI) → Unix Socket → Argus.app → Notch UI
```

### Two Build Targets

1. **Argus.app** — SwiftUI/AppKit menu-bar-less app that renders in the notch area
2. **argus-bridge** — Standalone Swift CLI binary (zero dependencies) that hooks install into agent configs. Reads JSON from stdin, forwards to Unix socket at `~/.argus/argus.sock`

### Core Data Flow

- `AppDelegate` bootstraps everything: creates `NotchWindowController`, starts `SocketServer`, installs hooks, scans for existing sessions
- `SocketServer` listens on `~/.argus/argus.sock` (AF_UNIX, SOCK_STREAM), parses JSONL messages into `HookEvent`
- `SessionStore` processes events, manages `Session` lifecycle and state transitions (`idle → working → waiting → idle`)
- `AppState` is the `@Observable` bridge between business logic and SwiftUI views
- For blocking events (permission requests), the socket connection stays open until the user responds via the UI

### Hook System

- `HookInstaller` manages installation/uninstallation of hooks for all supported agents
- `HookConfigMerger` handles merging Argus bridge commands into each agent's config file (JSON) without touching existing hooks
- Three hook formats exist: `.claude` (matcher + hooks array), `.nested` (hooks array), `.flat` (direct command)
- Hook configs are backed up before first modification (`.argus-backup` suffix)
- Hooks are verified and repaired every 5 minutes via a timer in `AppDelegate`

### Multi-Agent Support

`AgentSource` enum defines all supported agents with their config paths, event mappings, hook formats, and display properties. Each agent has different event names that map to Argus's internal `HookEventType`.

### Window System

- `NotchWindowController` manages a transparent `NotchWindow` (NSPanel) positioned at the top of the screen over the notch
- `PassThroughHostingView` allows mouse events to pass through except in the active hit-test rect
- Panel states: `hidden → compact → expanded` controlled by hover detection and pending interactions
- Fullscreen support with a 5pt trigger zone at the top of the screen

## Dependencies (SPM)

- `KeyboardShortcuts` (sindresorhus) — Global keyboard shortcuts (Cmd+Y/N for permissions, Cmd+1/2/3 for questions)
- `LaunchAtLogin-Modern` (sindresorhus) — Launch at login support
- `Sparkle` — Auto-update framework

## Localization

Uses `Localizable.strings` files in `Resources/` with a custom `L10n` helper enum that supports runtime language switching. Supported languages: tr, en, ko, pt-BR, de, es, fr, ja, zh-Hans.

## Key Patterns

- The app has no visible windows — it lives entirely in the notch panel (no dock icon, no standard menu bar)
- `@Observable` (Swift Observation framework) is used for state management, not `ObservableObject`/Combine
- Settings are persisted via `UserDefaults` with `didSet` observers in `SettingsStore`
- Session cleanup uses a 5-second timer to check if discovered processes (by PID) are still alive
- `SmartSuppress` prevents redundant sound notifications when the user is actively watching a session
- `WindowJumper` detects and can jump to the terminal/IDE window that owns a session

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode with Swift 6 toolchain
