import AppKit
import Observation

@MainActor
final class OverlayManager {
    private var overlays: [CGDirectDisplayID: (window: OverlayWindow, contentView: OverlayContentView)] = [:]
    private let appState: AppState
    private let poller: WindowPoller
    private let notchEars = NotchEarOverlay()
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
        // If app is already enabled, immediately show the new overlays
        if appState.isEnabled {
            wasEnabled = false  // Force re-trigger of enable transition
        }
    }

    func removeAllOverlays() {
        for (_, entry) in overlays {
            entry.contentView.teardown()
            entry.window.close()
        }
        overlays.removeAll()
        notchEars.teardown()
        overlaysVisible = false
    }

    func update() {
        // Handle disable: fade out and return early
        if !appState.isEnabled {
            if wasEnabled {
                wasEnabled = false
                for (_, entry) in overlays {
                    entry.contentView.teardown()
                    entry.window.fadeOut()
                }
                notchEars.hide()
                overlaysVisible = false
                lastSnapshots = []
            }
            return
        }

        // Handle enable transition
        if !wasEnabled {
            wasEnabled = true
            for (_, entry) in overlays {
                entry.window.fadeIn()
            }
            overlaysVisible = true
        }

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
        notchEars.updateEffects(state: appState)

        // Check fullscreen to swap main overlays for notch ear overlays
        let fsScreen = fullscreenScreen()
        let isFocusedAppFullscreen = fsScreen != nil

        if isFocusedAppFullscreen {
            // Fullscreen: hide main overlays, show ears in notch area
            if overlaysVisible {
                for (_, entry) in overlays {
                    entry.window.orderOut(nil)
                }
                overlaysVisible = false
            }
            if let screen = fsScreen {
                notchEars.show(on: screen, state: appState)
            }
            return
        }

        // Not fullscreen: main overlay covers ears already, hide ear windows
        notchEars.hide()

        let snapshots = poller.focusedSnapshots
        let focusChanged = snapshots != lastSnapshots

        if focusChanged || !overlaysVisible {
            lastSnapshots = snapshots
            let topWindowID = snapshots.first?.windowID

            for (_, entry) in overlays {
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
            overlaysVisible = true
        } else {
            // Safety: ensure overlay windows are on screen even if no focus change.
            // Fixes startup race where poller hasn't detected windows yet.
            for (_, entry) in overlays where !entry.window.isVisible {
                entry.window.orderFrontRegardless()
            }
        }
    }

    /// Returns the screen where the frontmost app is in native fullscreen, or nil.
    private func fullscreenScreen() -> NSScreen? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let w = bounds["Width"] as? CGFloat,
                  let h = bounds["Height"] as? CGFloat,
                  let x = bounds["X"] as? CGFloat,
                  let _ = bounds["Y"] as? CGFloat
            else { continue }

            for screen in NSScreen.screens {
                let sf = screen.frame
                // On notched MacBooks, fullscreen apps in compatibility mode
                // are shorter by safeAreaInsets.top (they don't extend behind the notch)
                let notchInset = screen.safeAreaInsets.top
                let matchesFull = abs(h - sf.height) < 2
                let matchesBelowNotch = notchInset > 0 && abs(h - (sf.height - notchInset)) < 2
                let displayMatch = abs(w - sf.width) < 2
                    && (matchesFull || matchesBelowNotch)
                    && abs(x - sf.origin.x) < 2
                if displayMatch {
                    return screen
                }
            }
        }
        return nil
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

                // Re-check after fullscreen animation completes (~0.7s)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    MainActor.assumeIsolated {
                        self?.lastSnapshots = []
                        self?.update()
                    }
                }
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
