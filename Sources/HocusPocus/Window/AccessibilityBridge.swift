import AppKit
import ApplicationServices

@MainActor
enum AccessibilityBridge {

    private static var hasPrompted = false
    private static var isTrusted = false

    static func focusedWindowFrame(for pid: pid_t) -> CGRect? {
        // Skip AX entirely if we don't have permission (avoids log spam)
        guard isTrusted else { return nil }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow
        )
        guard result == .success, let window = focusedWindow else { return nil }
        // swiftlint:disable:next force_cast
        let windowElement = window as! AXUIElement

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            windowElement, kAXPositionAttribute as CFString, &positionValue
        ) == .success,
        AXUIElementCopyAttributeValue(
            windowElement, kAXSizeAttribute as CFString, &sizeValue
        ) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero

        // swiftlint:disable:next force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    /// Prompt the user for accessibility permission exactly once.
    /// After granting, call `refreshTrustStatus()` or it will pick up on next silent check.
    static func promptIfNeeded() {
        guard !hasPrompted else { return }
        hasPrompted = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    /// Silent check -- no prompt dialog. Call periodically to detect when user grants permission.
    static func refreshTrustStatus() {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }
}
