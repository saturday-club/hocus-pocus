import AppKit
import ApplicationServices
import Observation

@Observable
@MainActor
final class WindowPoller {
    private(set) var focusedSnapshots: [WindowSnapshot] = []
    private var timer: Timer?
    private let appState: AppState
    private var lastFrontmostPID: pid_t = 0
    private var trustCheckCounter = 0
    private var stableCounter = 0

    // AX observer for event-driven focus changes
    private var axObserver: AXObserver?
    private var needsUpdate = true
    private var clickMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
    }

    func start() {
        setupWorkspaceObservers()
        setupClickMonitor()

        // Fallback poll at 10Hz (AX observers handle the fast path)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
    }

    /// Detect mouse clicks globally so we can immediately re-poll when user clicks a window.
    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.needsUpdate = true
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        teardownAXObserver()
        focusedSnapshots = []
    }

    private func setupWorkspaceObservers() {
        // React instantly to app switches
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.needsUpdate = true
                // Rebuild AX observer for the new frontmost app
                if let app = NSWorkspace.shared.frontmostApplication {
                    self?.setupAXObserver(for: app.processIdentifier)
                }
            }
        }
    }

    private func setupAXObserver(for pid: pid_t) {
        teardownAXObserver()

        var observer: AXObserver?
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let result = AXObserverCreate(pid, { (_, _, _, refcon) in
            guard let refcon else { return }
            let poller = Unmanaged<WindowPoller>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    poller.needsUpdate = true
                }
            }
        }, &observer)

        guard result == .success, let observer else { return }

        let appElement = AXUIElementCreateApplication(pid)
        let notifications: [CFString] = [
            kAXFocusedWindowChangedNotification as CFString,
            kAXWindowMovedNotification as CFString,
            kAXWindowResizedNotification as CFString,
            kAXWindowMiniaturizedNotification as CFString,
            kAXWindowDeminiaturizedNotification as CFString,
        ]

        for notif in notifications {
            AXObserverAddNotification(observer, appElement, notif, refcon)
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .defaultMode
        )

        self.axObserver = observer
    }

    private func teardownAXObserver() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        axObserver = nil
    }

    private func poll() {
        // Recheck accessibility trust every ~5 seconds
        trustCheckCounter += 1
        if trustCheckCounter >= 50 {
            trustCheckCounter = 0
            AccessibilityBridge.refreshTrustStatus()
        }

        guard appState.isEnabled else {
            if !focusedSnapshots.isEmpty {
                focusedSnapshots = []
            }
            return
        }

        // Skip poll if nothing changed (event-driven path handles updates)
        if !needsUpdate {
            stableCounter += 1
            // Force a poll every ~2 seconds as safety net
            if stableCounter < 20 { return }
        }
        needsUpdate = false
        stableCounter = 0

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        if let bundleID = frontApp.bundleIdentifier,
           appState.excludedApps.contains(bundleID) {
            if !focusedSnapshots.isEmpty { focusedSnapshots = [] }
            return
        }

        // Setup AX observer if PID changed
        if pid != lastFrontmostPID {
            setupAXObserver(for: pid)
            lastFrontmostPID = pid
        }

        let axFrame = AccessibilityBridge.focusedWindowFrame(for: pid)

        let windowListInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        let appWindows = windowListInfo.compactMap { info -> WindowSnapshot? in
            guard let snapshot = WindowSnapshot.fromCGWindowInfo(info),
                  snapshot.ownerPID == pid else { return nil }
            guard snapshot.frame.width > 50 && snapshot.frame.height > 50 else { return nil }
            return snapshot
        }

        if appState.highlightAllAppWindows {
            if appWindows != focusedSnapshots {
                focusedSnapshots = appWindows
            }
        } else {
            if let axFrame = axFrame {
                let matched = appWindows.first { s in
                    abs(s.frame.origin.x - axFrame.origin.x) < 5
                    && abs(s.frame.origin.y - axFrame.origin.y) < 5
                    && abs(s.frame.width - axFrame.width) < 5
                    && abs(s.frame.height - axFrame.height) < 5
                }
                let best = matched.map {
                    WindowSnapshot(
                        windowID: $0.windowID, frame: axFrame,
                        ownerPID: $0.ownerPID, ownerName: $0.ownerName,
                        windowName: $0.windowName, displayID: $0.displayID
                    )
                } ?? appWindows.first
                let result = best.map { [$0] } ?? []
                if result != focusedSnapshots { focusedSnapshots = result }
            } else if let first = appWindows.first {
                if focusedSnapshots != [first] { focusedSnapshots = [first] }
            } else {
                if !focusedSnapshots.isEmpty { focusedSnapshots = [] }
            }
        }
    }
}
