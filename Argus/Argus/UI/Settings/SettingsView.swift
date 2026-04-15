import SwiftUI
import UniformTypeIdentifiers
import LaunchAtLogin
import KeyboardShortcuts

// MARK: - Settings Tab Model

private enum SettingsTab: String, CaseIterable {
    case general, appearance, pets, sounds, shortcuts, hooks

    var title: String {
        switch self {
        case .general:    L10n["settings.tab.general"]
        case .appearance: L10n["settings.tab.appearance"]
        case .pets:       L10n["settings.tab.pets"]
        case .sounds:     L10n["settings.tab.sounds"]
        case .shortcuts:  L10n["settings.tab.shortcuts"]
        case .hooks:      L10n["settings.tab.hooks"]
        }
    }

    var icon: String {
        switch self {
        case .general:    "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .pets:       "pawprint.fill"
        case .sounds:     "speaker.wave.2.fill"
        case .shortcuts:  "keyboard"
        case .hooks:      "link.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:    .gray
        case .appearance: .purple
        case .pets:       .orange
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
        .id(settingsStore.languageVersion)
    }

    private var sidebar: some View {
        VStack(spacing: 2) {
            // App header
            VStack(spacing: 6) {
                Image(systemName: "airplane")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                Text("Argus")
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
            case .pets:       PetsTab(store: settingsStore)
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
            .contentShape(Rectangle())
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
            SettingsSection(title: L10n["settings.section.startup"], icon: "power", color: .green) {
                LaunchAtLogin.Toggle {
                    Text(L10n["settings.general.autoLaunch"])
                }
            }

            SettingsSection(title: L10n["settings.section.language"], icon: "globe", color: .cyan) {
                Picker("", selection: $store.language) {
                    Text(L10n["language.system"]).tag("system")
                    Divider()
                    Text("Turkce").tag("tr")
                    Text("English").tag("en")
                    Text("Deutsch").tag("de")
                    Text("Espanol").tag("es")
                    Text("Francais").tag("fr")
                    Text("日本語").tag("ja")
                    Text("中文").tag("zh")
                    Text("한국어").tag("ko")
                    Text("Portugues (BR)").tag("pt-BR")
                }
            }

            SettingsSection(title: L10n["settings.section.behavior"], icon: "slider.horizontal.3", color: .blue) {
                Toggle(L10n["settings.behavior.showInFullscreen"], isOn: $store.showInFullscreen)
                Toggle(L10n["settings.behavior.nativeNotifications"], isOn: $store.nativeNotificationsEnabled)

                HStack {
                    Text(L10n["settings.behavior.idleTimeout"])
                    Spacer()
                    Picker("", selection: $store.idleTimeout) {
                        Text(L10n["settings.behavior.timeout.5min"]).tag(TimeInterval(300))
                        Text(L10n["settings.behavior.timeout.10min"]).tag(TimeInterval(600))
                        Text(L10n["settings.behavior.timeout.15min"]).tag(TimeInterval(900))
                        Text(L10n["settings.behavior.timeout.30min"]).tag(TimeInterval(1800))
                    }
                    .frame(width: 100)
                }
            }

            SettingsSection(title: L10n["settings.section.monitor"], icon: "display", color: .cyan) {
                Picker(L10n["settings.monitor.screen"], selection: Binding(
                    get: { store.selectedScreenName ?? "auto" },
                    set: { newValue in
                        store.selectedScreenName = newValue == "auto" ? nil : newValue
                        store.onScreenChanged?()
                    }
                )) {
                    Text(L10n["settings.monitor.auto"]).tag("auto")
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
            }

            SettingsSection(title: L10n["settings.section.accessibility"], icon: "hand.raised.fill", color: .orange) {
                let trusted = AXIsProcessTrusted()
                HStack {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? .green : .orange)
                    Text(trusted ? L10n["settings.accessibility.enabled"] : L10n["settings.accessibility.required"])
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

            SettingsSection(title: L10n["settings.section.voiceCommand"], icon: "mic.fill", color: .red) {
                Toggle(L10n["settings.voiceCommand.enable"], isOn: $store.voiceCommandEnabled)
                Text(L10n["settings.voiceCommand.description"])
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            SettingsSection(title: L10n["settings.section.update"], icon: "arrow.triangle.2.circlepath", color: .green) {
                HStack {
                    Text("Argus v1.0")
                        .font(.system(size: 12))
                    Spacer()
                    Button(L10n["settings.button.checkUpdate"]) {
                        UpdateManager().checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
            SettingsSection(title: L10n["settings.section.theme"], icon: "moon.fill", color: .indigo) {
                Picker("", selection: $store.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            SettingsSection(title: L10n["settings.section.accentColor"], icon: "paintpalette.fill", color: .purple) {
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
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(L10n["settings.appearance.showBorder"], isOn: $store.showBorder)

                HStack(spacing: 12) {
                    Text(L10n["settings.appearance.idleOpacity"])
                        .font(.system(size: 12))
                    Slider(value: $store.idleOpacity, in: 0.1...1.0)
                        .tint(store.accentColor)
                    Text("\(Int(store.idleOpacity * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSection(title: L10n["settings.section.compactBar"], icon: "rectangle.topthird.inset.filled", color: .teal) {
                HStack {
                    Text(L10n["settings.compactBar.width"])
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $store.barWidth) {
                        ForEach(BarWidth.allCases, id: \.self) { w in
                            Text(w.displayName).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                HStack(spacing: 12) {
                    Text(L10n["settings.compactBar.height"])
                        .font(.system(size: 12))
                    Slider(value: $store.barHeight, in: 24...44, step: 2)
                        .tint(.teal)
                    Text("\(Int(store.barHeight))pt")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text(L10n["settings.compactBar.cornerRadius"])
                        .font(.system(size: 12))
                    Slider(value: $store.cornerRadius, in: 4...24, step: 1)
                        .tint(.teal)
                    Text("\(Int(store.cornerRadius))pt")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text(L10n["settings.compactBar.fontSize"])
                        .font(.system(size: 12))
                    Slider(value: $store.fontSize, in: 9...16, step: 0.5)
                        .tint(.teal)
                    Text("\(String(format: "%.1f", store.fontSize))")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text(L10n["settings.compactBar.horizontalOffset"])
                        .font(.system(size: 12))
                    Slider(value: $store.barOffset, in: -1...1, step: 0.05)
                        .tint(.teal)
                    Text(store.barOffset == 0 ? L10n["settings.compactBar.offset.center"] : store.barOffset < 0 ? L10n["settings.compactBar.offset.left"] : L10n["settings.compactBar.offset.right"])
                        .font(.system(size: 11))
                        .frame(width: 36, alignment: .trailing)
                        .foregroundStyle(.secondary)
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

// MARK: - Pets Tab

private struct PetsTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: L10n["settings.section.notchStatusIcon"], icon: "pawprint.fill", color: .mint) {
                HStack(spacing: 10) {
                    ForEach(PetStyle.allCases, id: \.self) { pet in
                        Button(action: { store.petStyle = pet }) {
                            VStack(spacing: 4) {
                                if pet == .dot {
                                    Circle().fill(.green).frame(width: 16, height: 16)
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
                            .background(RoundedRectangle(cornerRadius: 8).fill(store.petStyle == pet ? store.accentColor.opacity(0.15) : .clear))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.petStyle == pet ? store.accentColor : .clear, lineWidth: 1.5))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            SettingsSection(title: L10n["settings.section.deskPet"], icon: "cat.fill", color: .orange) {
                Toggle(L10n["settings.deskPet.enabled"], isOn: $store.deskPetEnabled)

                if store.deskPetEnabled {
                    Picker(L10n["settings.deskPet.type"], selection: $store.deskPetType) {
                        Text(L10n["deskpet.type.cat"]).tag("cat")
                        Text(L10n["deskpet.type.dog"]).tag("dog")
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        Text(L10n["settings.deskPet.size"])
                            .font(.system(size: 12))
                        Slider(value: $store.deskPetSize, in: 16...64, step: 4)
                            .tint(.orange)
                        Text("\(Int(store.deskPetSize))px")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.deskPetEnabled && store.deskPetType == "dog" {
                SettingsSection(title: L10n["settings.section.dogBreed"], icon: "dog.fill", color: .brown) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(dogBreeds, id: \.name) { dog in
                            Button(action: { store.dogBreed = dog.name }) {
                                VStack(spacing: 4) {
                                    dogPreview(dog.name)
                                    Text(dog.display)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(store.dogBreed == dog.name ? store.accentColor.opacity(0.15) : .clear))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.dogBreed == dog.name ? store.accentColor : .clear, lineWidth: 1.5))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if store.deskPetEnabled && store.deskPetType == "cat" {
                SettingsSection(title: L10n["settings.section.catColor"], icon: "cat.fill", color: .orange) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                        ForEach(catColors, id: \.name) { cat in
                            Button(action: { store.catColor = cat.name }) {
                                VStack(spacing: 4) {
                                    catPreview(cat.name)
                                    Text(cat.display)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(store.catColor == cat.name ? store.accentColor.opacity(0.15) : .clear))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.catColor == cat.name ? store.accentColor : .clear, lineWidth: 1.5))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dogPreview(_ breed: String) -> some View {
        let fileName = "\(breed)-idle"
        if let url = Bundle.main.url(forResource: fileName, withExtension: "png"),
           let img = NSImage(contentsOf: url),
           let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let cropped = cgImg.cropping(to: CGRect(x: 0, y: 0, width: 64, height: 64)) {
            Image(nsImage: NSImage(cgImage: cropped, size: NSSize(width: 64, height: 64)))
                .interpolation(.none).resizable().frame(width: 32, height: 32)
        } else {
            Text("🐶").font(.system(size: 18)).frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private func catPreview(_ name: String) -> some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url),
           let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let cropped = cgImg.cropping(to: CGRect(x: 0, y: 0, width: 32, height: 32)) {
            Image(nsImage: NSImage(cgImage: cropped, size: NSSize(width: 32, height: 32)))
                .interpolation(.none).resizable().frame(width: 32, height: 32)
        } else {
            Rectangle().fill(.gray).frame(width: 32, height: 32)
        }
    }

    private var dogBreeds: [(name: String, display: String)] {
        [("golden", "Golden"), ("husky", "Husky"), ("dalmatian", "Dalmatian"), ("rottweiler", "Rottweiler"),
         ("canecorso", "Cane Corso"), ("dogoargentino", "Dogo Argentino"), ("labrador", "Labrador"), ("pharaoh", "Pharaoh Hound")]
    }

    private var catColors: [(name: String, display: String)] {
        [("black-cat", "Siyah"), ("orange-cat", "Turuncu"), ("white-cat", "Beyaz"),
         ("grey-cat", "Gri"), ("calico-cat", "Calico"), ("colorpoint-cat", "Colorpoint")]
    }
}

// MARK: - Sounds Tab

private struct SoundsTab: View {
    @Bindable var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: L10n["settings.sounds.general"], icon: "speaker.wave.2.fill", color: .pink) {
                Toggle(L10n["settings.sounds.enabled"], isOn: $store.soundEnabled)

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

            SettingsSection(title: L10n["settings.sounds.eventSounds"], icon: "bell.badge.fill", color: .yellow) {
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

                        Text(config.customSoundURL?.lastPathComponent ?? L10n["settings.sounds.system"])
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
            SettingsSection(title: L10n["settings.section.permissionShortcuts"], icon: "shield.fill", color: .green) {
                KeyboardShortcuts.Recorder(L10n["shortcuts.allow"], name: .allowPermission)
                KeyboardShortcuts.Recorder(L10n["shortcuts.deny"], name: .denyPermission)
            }

            SettingsSection(title: L10n["settings.section.questionShortcuts"], icon: "questionmark.circle.fill", color: .blue) {
                KeyboardShortcuts.Recorder(L10n["shortcuts.option1"], name: .questionOption1)
                KeyboardShortcuts.Recorder(L10n["shortcuts.option2"], name: .questionOption2)
                KeyboardShortcuts.Recorder(L10n["shortcuts.option3"], name: .questionOption3)
            }

            SettingsSection(title: L10n["settings.section.panel"], icon: "rectangle.topthird.inset.filled", color: .orange) {
                KeyboardShortcuts.Recorder(L10n["shortcuts.togglePanel"], name: .togglePanel)
            }
        }
    }
}

// MARK: - Hooks Tab

private struct HooksTab: View {
    @Bindable var store: SettingsStore
    let hookInstaller: HookInstaller
    @State private var agentStatus: [AgentSource: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: L10n["settings.section.agentStatus"], icon: "cpu", color: .purple) {
                ForEach(AgentSource.allCases, id: \.self) { agent in
                    HStack(spacing: 10) {
                        Toggle(agent.displayName, isOn: Binding(
                            get: { store.enabledAgents.contains(agent.rawValue) },
                            set: { enabled in
                                if enabled {
                                    store.enabledAgents.insert(agent.rawValue)
                                    _ = hookInstaller.installHooks(for: agent)
                                } else {
                                    store.enabledAgents.remove(agent.rawValue)
                                    _ = hookInstaller.uninstallHooks(for: agent)
                                }
                                refreshStatus()
                            }
                        ))
                        .toggleStyle(.switch)
                        .font(.system(size: 12, weight: .medium))

                        Spacer()

                        let installed = agentStatus[agent] ?? false
                        Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(installed ? .green : .secondary)
                    }
                }
            }
        }
        .onAppear { refreshStatus() }
    }

    private func refreshStatus() {
        for agent in AgentSource.allCases {
            agentStatus[agent] = hookInstaller.hooksAreInstalled(for: agent)
        }
    }
}
