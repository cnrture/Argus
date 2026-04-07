import SwiftUI

@main
struct NotchPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchPilot", systemImage: "airplane") {
            Text("NotchPilot")
                .font(.headline)
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
