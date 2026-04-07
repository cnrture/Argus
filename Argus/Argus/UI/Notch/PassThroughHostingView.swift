import SwiftUI

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var hitTestRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRect.contains(point) else { return nil }
        return super.hitTest(point)
    }
}
