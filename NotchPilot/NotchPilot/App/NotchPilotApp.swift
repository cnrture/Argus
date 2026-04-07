import SwiftUI

@main
struct NotchPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchPilot", systemImage: "airplane") {
            Text("NotchPilot")
                .font(.headline)

            Divider()

            Button(appDelegate.settingsStore.soundEnabled ? "Sesi Kapat" : "Sesi Aç") {
                appDelegate.settingsStore.soundEnabled.toggle()
            }

            Button("Ayarlar...") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Çıkış") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
