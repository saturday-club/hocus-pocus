import AppKit

final class OverlayWindow: NSWindow {

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        level = .normal
        collectionBehavior = [
            .canJoinAllSpaces,   // Follow across Spaces (including fullscreen Spaces)
            .stationary,         // Don't move with Space transitions
            .fullScreenAuxiliary, // Can appear alongside fullscreen windows
            .transient           // Don't show in Mission Control
        ]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Order this overlay just below the given window number.
    func orderBelow(windowNumber: Int) {
        order(.below, relativeTo: windowNumber)
    }

    /// Fade in with animation.
    func fadeIn(duration: TimeInterval = 0.3) {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    /// Fade out with animation.
    func fadeOut(duration: TimeInterval = 0.25) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                self.orderOut(nil)
                self.alphaValue = 1.0
            }
        })
    }

    func reposition(to screen: NSScreen) {
        setFrame(screen.frame, display: true)
    }
}
