import AppKit
import Observation

@MainActor
final class OverlayManager {
    private var overlays: [CGDirectDisplayID: (window: OverlayWindow, contentView: OverlayContentView)] = [:]
    private let appState: AppState
    private let poller: WindowPoller
    private var lastSnapshots: [WindowSnapshot] = []
    private var overlaysVisible = false
    private var wasEnabled = false

    init(appState: AppState, poller: WindowPoller) {
        self.appState = appState
        self.poller = poller
        setupDisplayNotifications()
        setupSpaceNotifications()
    }

    func createOverlays() {
        removeAllOverlays()
        for screen in NSScreen.screens {
            createOverlay(for: screen)
        }
    }

    func removeAllOverlays() {
        for (_, entry) in overlays {
            entry.contentView.teardown()
            entry.window.close()
        }
        overlays.removeAll()
        overlaysVisible = false
    }

    func update() {
        // Handle enable/disable transitions with fade animation
        if appState.isEnabled && !wasEnabled {
            wasEnabled = true
            for (_, entry) in overlays {
                entry.window.fadeIn()
            }
            overlaysVisible = true
        } else if !appState.isEnabled && wasEnabled {
            wasEnabled = false
            for (_, entry) in overlays {
                entry.contentView.teardown()
                entry.window.fadeOut()
            }
            overlaysVisible = false
            lastSnapshots = []
            return
        }

        guard appState.isEnabled else { return }

        // Reconcile displays
        let currentDisplayIDs = Set(overlays.keys)
        let activeScreens = NSScreen.screens
        let activeDisplayIDs = Set(activeScreens.map { $0.displayID })

        for displayID in currentDisplayIDs.subtracting(activeDisplayIDs) {
            if let entry = overlays.removeValue(forKey: displayID) {
                entry.contentView.teardown()
                entry.window.close()
            }
        }

        for screen in activeScreens where !currentDisplayIDs.contains(screen.displayID) {
            createOverlay(for: screen)
        }

        // Always push effects
        for (_, entry) in overlays {
            entry.contentView.updateEffects(state: appState)
        }

        let snapshots = poller.focusedSnapshots
        let focusChanged = snapshots != lastSnapshots

        if focusChanged || !overlaysVisible {
            lastSnapshots = snapshots

            let topWindowID = snapshots.first?.windowID
            let isFocusedAppFullscreen = checkIfFocusedAppIsFullscreen()

            for (_, entry) in overlays {
                if isFocusedAppFullscreen {
                    // Fullscreen: just hide. The app fills the screen, no dimming needed.
                    entry.window.orderOut(nil)
                } else {
                    if let wid = topWindowID {
                        entry.window.orderBelow(windowNumber: Int(wid))
                    } else {
                        entry.window.orderFrontRegardless()
                    }

                    if appState.mode == .ambient {
                        let windowsByDisplay = Dictionary(
                            grouping: snapshots,
                            by: { $0.displayID }
                        )
                        let screen = entry.window.screen ?? NSScreen.main!
                        let frames = windowsByDisplay[screen.displayID]?.map(\.frame) ?? []
                        entry.contentView.updateFocusRegion(
                            frames: frames,
                            mode: .ambient
                        )
                    } else {
                        entry.contentView.clearMask()
                    }
                }
            }

            overlaysVisible = !isFocusedAppFullscreen
        }
    }

    /// Check if the frontmost application is currently in native macOS fullscreen.
    private func checkIfFocusedAppIsFullscreen() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = frontApp.processIdentifier

        // Check via CGWindowList: if the app has a window at layer 0 matching the full screen size,
        // and the screen's visibleFrame equals its full frame, it's likely fullscreen
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let w = bounds["Width"] as? CGFloat,
                  let h = bounds["Height"] as? CGFloat,
                  let x = bounds["X"] as? CGFloat,
                  let _ = bounds["Y"] as? CGFloat
            else { continue }

            // Check if this window covers the full display (fullscreen indicator)
            for screen in NSScreen.screens {
                let sf = screen.frame
                let displayMatch = abs(w - sf.width) < 2 && abs(h - sf.height) < 2
                    && abs(x - sf.origin.x) < 2
                if displayMatch {
                    // Window covers the full screen -- it's fullscreen
                    return true
                }
            }
        }
        return false
    }

    private func createOverlay(for screen: NSScreen) {
        let window = OverlayWindow(screen: screen)
        let contentView = OverlayContentView(frame: screen.frame, screen: screen)
        window.contentView = contentView
        overlays[screen.displayID] = (window, contentView)
    }

    private func setupDisplayNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.createOverlays()
                self?.update()
            }
        }
    }

    private func setupSpaceNotifications() {
        // Detect Space changes (including fullscreen transitions)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Force re-evaluation after a Space switch
                self?.lastSnapshots = []
                self?.update()
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? CGMainDisplayID()
    }
}
