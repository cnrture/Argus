import SwiftUI
import UniformTypeIdentifiers
import LaunchAtLogin
import KeyboardShortcuts

struct SettingsView: View {
    @State var settingsStore: SettingsStore
    let hookInstaller: HookInstaller

    var body: some View {
        TabView {
            GeneralTab(store: settingsStore)
                .tabItem { Label("Genel", systemImage: "gearshape") }
            AppearanceTab(store: settingsStore)
                .tabItem { Label("Görünüm", systemImage: "paintbrush") }
            SoundsTab(store: settingsStore)
                .tabItem { Label("Sesler", systemImage: "speaker.wave.2") }
            ShortcutsTab()
                .tabItem { Label("Kısayollar", systemImage: "keyboard") }
            HooksTab(store: settingsStore, hookInstaller: hookInstaller)
                .tabItem { Label("Hooks", systemImage: "link") }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            LaunchAtLogin.Toggle("Giriş'te otomatik başlat")

            Toggle("Fullscreen uygulamalarda göster", isOn: $store.showInFullscreen)
            Toggle("macOS bildirimleri gönder", isOn: $store.nativeNotificationsEnabled)

            Picker("Hareketsizlik süresi", selection: $store.idleTimeout) {
                Text("5 dakika").tag(TimeInterval(300))
                Text("10 dakika").tag(TimeInterval(600))
                Text("15 dakika").tag(TimeInterval(900))
                Text("30 dakika").tag(TimeInterval(1800))
            }

            // Monitor selection
            Picker("Monitör", selection: Binding(
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

            // Accessibility status
            let trusted = AXIsProcessTrusted()
            HStack {
                Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(trusted ? .green : .orange)
                Text(trusted ? "Accessibility erişimi aktif" : "Accessibility erişimi gerekli")
                    .font(.caption)
                Spacer()
                if !trusted {
                    Button("Aç") {
                        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        NSWorkspace.shared.open(URL(string: url)!)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Picker("Tema", selection: $store.theme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Picker("Accent Renk", selection: $store.accentColorName) {
                Text("Turuncu").tag("orange")
                Text("Mavi").tag("blue")
                Text("Mor").tag("purple")
                Text("Yeşil").tag("green")
                Text("Kırmızı").tag("red")
            }
        }
        .padding()
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        Form {
            Toggle("Sesler aktif", isOn: $store.soundEnabled)

            HStack {
                Text("Ses seviyesi")
                Slider(value: $store.soundVolume, in: 0...1)
                Text("\(Int(store.soundVolume * 100))%")
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }

            Divider()

            ForEach(Array(store.soundEvents.enumerated()), id: \.element.id) { index, config in
                HStack {
                    Text(config.eventType.displayName)
                        .frame(width: 140, alignment: .leading)
                    Toggle("", isOn: Binding(
                        get: { store.soundEvents[index].enabled },
                        set: { store.soundEvents[index].enabled = $0 }
                    ))
                    .labelsHidden()
                    Spacer()
                    Text(config.customSoundURL?.lastPathComponent ?? "Varsayılan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Değiştir") {
                        selectSound(for: index)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
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
}

// MARK: - Shortcuts Tab

private struct ShortcutsTab: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("İzin Ver:", name: .allowPermission)
            KeyboardShortcuts.Recorder("Reddet:", name: .denyPermission)
            KeyboardShortcuts.Recorder("Seçenek 1:", name: .questionOption1)
            KeyboardShortcuts.Recorder("Seçenek 2:", name: .questionOption2)
            KeyboardShortcuts.Recorder("Seçenek 3:", name: .questionOption3)
            KeyboardShortcuts.Recorder("Panel Aç/Kapat:", name: .togglePanel)
        }
        .padding()
    }
}

// MARK: - Hooks Tab

private struct HooksTab: View {
    @Bindable var store: SettingsStore
    let hookInstaller: HookInstaller
    @State private var hooksInstalled: Bool = false

    var body: some View {
        Form {
            Toggle("Claude Code hook'larını otomatik kur", isOn: $store.autoSetupHooks)

            HStack {
                Image(systemName: hooksInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(hooksInstalled ? .green : .red)
                Text(hooksInstalled ? "Hook'lar aktif" : "Hook'lar kurulu değil")
            }

            Text("~/.claude/settings.json")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Hook'ları Yeniden Kur") {
                    _ = hookInstaller.installHooks()
                    hooksInstalled = hookInstaller.hooksAreInstalled()
                }
                Button("Hook'ları Kaldır") {
                    _ = hookInstaller.uninstallHooks()
                    hooksInstalled = hookInstaller.hooksAreInstalled()
                }
            }
        }
        .padding()
        .onAppear { hooksInstalled = hookInstaller.hooksAreInstalled() }
    }
}
