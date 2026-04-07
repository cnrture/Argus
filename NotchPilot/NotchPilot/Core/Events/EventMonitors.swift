import AppKit

final class EventMonitors {
    private var mouseMoveMonitor: EventMonitor?
    private var mouseDownMonitor: EventMonitor?

    var onMouseMove: ((NSPoint) -> Void)?
    var onMouseDown: ((NSPoint) -> Void)?

    func startAll() {
        mouseMoveMonitor = EventMonitor(mask: .mouseMoved) { [weak self] event in
            let location = NSEvent.mouseLocation
            self?.onMouseMove?(location)
        }
        mouseMoveMonitor?.start()

        mouseDownMonitor = EventMonitor(mask: .leftMouseDown) { [weak self] event in
            let location = NSEvent.mouseLocation
            self?.onMouseDown?(location)
        }
        mouseDownMonitor?.start()
    }

    func stopAll() {
        mouseMoveMonitor?.stop()
        mouseDownMonitor?.stop()
    }
}
