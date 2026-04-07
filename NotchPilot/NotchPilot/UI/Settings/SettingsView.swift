import SwiftUI
import UniformTypeIdentifiers
import LaunchAtLogin
import KeyboardShortcuts

// MARK: - Settings Tab Model

private enum SettingsTab: String, CaseIterable {
    case general, appearance, sounds, shortcuts, hooks

    var title: String {
        switch self {
        case .general:    "Genel"
        case .appearance: "Görünüm"
        case .sounds:     "Sesler"
        case .shortcuts:  "Kısayollar"
        case .hooks:      "Hooks"
        }
    }

    var icon: String {
        switch self {
        case .general:    "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .sounds:     "speaker.wave.2.fill"
        case .shortcuts:  "keyboard"
        case .hooks:      "link.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:    .gray
        case .appearance: .purple
        case .sounds:     .pink
        case .shortcuts:  .orange
        case .hooks:      .blue
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State var settingsStore: SettingsStore
    let hookInstaller: HookInstaller
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar

            // Divider
            Rectangle()
                .fill(.quaternary)
                .frame(width: 1)

            // Content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 500)
        .background(.background)
    }

    private var sidebar: some View {
        VStack(spacing: 2) {
            // App header
            VStack(spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text("NotchPilot")
                    .font(.system(size: 13, weight: .bold))
                Text("v1.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Tab buttons
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                SidebarButton(
                    title: tab.title,
                    icon: tab.icon,
                    color: tab.color,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }
            }

            Spacer()
        }
        .frame(width: 160)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            switch selectedTab {
            case .general:    GeneralTab(store: settingsStore)
            case .appearance: AppearanceTab(store: settingsStore)
            case .sounds:     SoundsTab(store: settingsStore)
            case .shortcuts:  ShortcutsTab()
            case .hooks:      HooksTab(store: settingsStore, hookInstaller: hookInstaller)
            }
        }
        .padding(24)
    }
}

// MARK: - Sidebar Button

private struct SidebarButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : color)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? color : color.opacity(0.12))
                    )

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Başlangıç", icon: "power", color: .green) {
                LaunchAtLogin.Toggle {
                    Text("Giriş'te otomatik başlat")
                }
            }

            SettingsSection(title: "Davranış", icon: "slider.horizontal.3", color: .blue) {
                Toggle("Fullscreen uygulamalarda göster", isOn: $store.showInFullscreen)
                Toggle("macOS bildirimleri gönder", isOn: $store.nativeNotificationsEnabled)

                HStack {
                    Text("Hareketsizlik süresi")
                    Spacer()
                    Picker("", selection: $store.idleTimeout) {
                        Text("5 dk").tag(TimeInterval(300))
                        Text("10 dk").tag(TimeInterval(600))
                        Text("15 dk").tag(TimeInterval(900))
                        Text("30 dk").tag(TimeInterval(1800))
                    }
                    .frame(width: 100)
                }
            }

            SettingsSection(title: "Monitör", icon: "display", color: .cyan) {
                Picker("Ekran", selection: Binding(
                    get: { store.selectedScreenName ?? "auto" },
                    set: { newValue in
                        store.selectedScreenName = newValue == "auto" ? nil : newValue
                        store.onScreenChanged?()
                    }
                )) {
                    Text("Otomatik (dahili ekran)").tag("auto")
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
            }

            SettingsSection(title: "Erişilebilirlik", icon: "hand.raised.fill", color: .orange) {
                let trusted = AXIsProcessTrusted()
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? "Accessibility erişimi aktif" : "Accessibility erişimi gerekli")
                    Spacer()
                    if !trusted {
                        Button("System Preferences") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Tema", icon: "moon.fill", color: .indigo) {
                Picker("", selection: $store.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection(title: "Accent Renk", icon: "paintpalette.fill", color: .purple) {
                HStack(spacing: 12) {
                    ForEach(accentColors, id: \.name) { item in
                        Button(action: { store.accentColorName = item.name }) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: store.accentColorName == item.name ? 2 : 0)
                                )
                                .shadow(color: item.color.opacity(0.4), radius: store.accentColorName == item.name ? 4 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle("Notch kenar cizgisi", isOn: $store.showBorder)
            }

            SettingsSection(title: "Durum Ikonu", icon: "pawprint.fill", color: .mint) {
                HStack(spacing: 10) {
                    ForEach(PetStyle.allCases, id: \.self) { pet in
                        Button(action: { store.petStyle = pet }) {
                            VStack(spacing: 4) {
                                if pet == .dot {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 16, height: 16)
                                } else {
                                    PixelArtView(
                                        pixels: pet.pixels(for: .working),
                                        palette: pet.palette(for: .working, accent: store.accentColor),
                                        pixelSize: 3
                                    )
                                    .frame(width: 24, height: 24)
                                }
                                Text(pet.displayName)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(store.petStyle == pet ? store.accentColor.opacity(0.15) : .clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(store.petStyle == pet ? store.accentColor : .clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var accentColors: [(name: String, color: Color)] {
        [
            ("orange", .orange),
            ("blue", .blue),
            ("purple", .purple),
            ("green", .green),
            ("red", .red),
            ("pink", .pink),
            ("cyan", .cyan),
        ]
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Genel", icon: "speaker.wave.2.fill", color: .pink) {
                Toggle("Sesler aktif", isOn: $store.soundEnabled)

                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Slider(value: $store.soundVolume, in: 0...1)
                        .tint(.pink)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                    Text("\(Int(store.soundVolume * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSection(title: "Olay Sesleri", icon: "bell.badge.fill", color: .yellow) {
                ForEach(Array(store.soundEvents.enumerated()), id: \.element.id) { index, config in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { store.soundEvents[index].enabled },
                            set: { store.soundEvents[index].enabled = $0 }
                        ))
                        .labelsHidden()
                        .tint(.pink)

                        Text(config.eventType.displayName)
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(config.customSoundURL?.lastPathComponent ?? "Sistem")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)

                        Button(action: { previewSound(config) }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(action: { selectSound(for: index) }) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if config.customSoundURL != nil {
                            Button(action: { store.soundEvents[index].customSoundURL = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }

                    if index < store.soundEvents.count - 1 {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }

    private func selectSound(for index: Int) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            store.soundEvents[index].customSoundURL = panel.url
        }
    }

    private func previewSound(_ config: SoundEventConfig) {
        SoundManager.shared.play(config.eventType, configs: [config])
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "İzin Kısayolları", icon: "shield.fill", color: .green) {
                KeyboardShortcuts.Recorder("İzin Ver", name: .allowPermission)
                KeyboardShortcuts.Recorder("Reddet", name: .denyPermission)
            }

            SettingsSection(title: "Soru Kısayolları", icon: "questionmark.circle.fill", color: .blue) {
                KeyboardShortcuts.Recorder("Seçenek 1", name: .questionOption1)
                KeyboardShortcuts.Recorder("Seçenek 2", name: .questionOption2)
                KeyboardShortcuts.Recorder("Seçenek 3", name: .questionOption3)
            }

            SettingsSection(title: "Panel", icon: "rectangle.topthird.inset.filled", color: .orange) {
                KeyboardShortcuts.Recorder("Panel Aç/Kapat", name: .togglePanel)
            }
        }
    }
}

// MARK: - Hooks Tab

private struct HooksTab: View {
    @Bindable var store: SettingsStore
    let hookInstaller: HookInstaller
    @State private var hooksInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "Claude Code Hooks", icon: "link.circle.fill", color: .blue) {
                Toggle("Hook'ları otomatik kur", isOn: $store.autoSetupHooks)

                HStack(spacing: 8) {
                    Image(systemName: hooksInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hooksInstalled ? .green : .red)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hooksInstalled ? "Hook'lar aktif" : "Hook'lar kurulu değil")
                            .font(.system(size: 12, weight: .medium))
                        Text("~/.claude/settings.json")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 8) {
                    Button(action: {
                        _ = hookInstaller.installHooks()
                        hooksInstalled = hookInstaller.hooksAreInstalled()
                    }) {
                        Label("Yeniden Kur", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.blue)

                    Button(action: {
                        _ = hookInstaller.uninstallHooks()
                        hooksInstalled = hookInstaller.hooksAreInstalled()
                    }) {
                        Label("Kaldır", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
        .onAppear { hooksInstalled = hookInstaller.hooksAreInstalled() }
    }
}
