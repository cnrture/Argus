import SwiftUI

@main
struct NotchPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchPilot", systemImage: "airplane") {
            MenuBarView(
                appState: appDelegate.appState,
                settingsStore: appDelegate.settingsStore,
                onOpenSettings: { appDelegate.openSettings() },
                onToggleSound: { appDelegate.settingsStore.soundEnabled.toggle() }
            )
        }

        Settings {
            SettingsView(
                settingsStore: appDelegate.settingsStore,
                hookInstaller: appDelegate.hookInstaller
            )
        }
    }
}
