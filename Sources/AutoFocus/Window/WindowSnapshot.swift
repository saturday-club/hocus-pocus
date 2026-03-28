import CoreGraphics

struct WindowSnapshot: Equatable, Sendable {
    let windowID: CGWindowID
    let frame: CGRect
    let ownerPID: pid_t
    let ownerName: String
    let windowName: String
    let displayID: CGDirectDisplayID

    static func fromCGWindowInfo(_ info: [String: Any]) -> WindowSnapshot? {
        guard let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
              let ownerName = info[kCGWindowOwnerName as String] as? String
        else { return nil }

        guard let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let w = boundsDict["Width"] as? CGFloat,
              let h = boundsDict["Height"] as? CGFloat
        else { return nil }

        let frame = CGRect(x: x, y: y, width: w, height: h)
        let windowName = info[kCGWindowName as String] as? String ?? ""

        // Determine which display contains the window center
        let center = CGPoint(x: frame.midX, y: frame.midY)
        var displayCount: UInt32 = 0
        var matchedDisplay: CGDirectDisplayID = CGMainDisplayID()
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 8)
        CGGetDisplaysWithPoint(center, 8, &displayIDs, &displayCount)
        if displayCount > 0 {
            matchedDisplay = displayIDs[0]
        }

        return WindowSnapshot(
            windowID: windowID,
            frame: frame,
            ownerPID: ownerPID,
            ownerName: ownerName,
            windowName: windowName,
            displayID: matchedDisplay
        )
    }
}
