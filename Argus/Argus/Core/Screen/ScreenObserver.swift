import AppKit

final class ScreenObserver {
    private var observer: NSObjectProtocol?

    init(onScreenChange: @escaping () -> Void) {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            onScreenChange()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
