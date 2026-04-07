import SwiftUI

@main
struct ArgusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes — app lives in the notch panel only
        Settings {
            EmptyView()
        }
    }
}
