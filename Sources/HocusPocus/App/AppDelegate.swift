import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayManager: OverlayManager?
    private var windowPoller: WindowPoller?
    private var hotkeyManager: HotkeyManager?
    private var shakeDetector: ShakeDetector?
    private var updateTimer: Timer?

    // Side panel + status item
    private var statusItem: NSStatusItem?
    private var sidePanelController: SidePanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState.shared

        // Prompt for accessibility once
        AccessibilityBridge.promptIfNeeded()

        // Status bar icon
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: appState.isEnabled ? "circle.fill" : "circle.dotted",
                accessibilityDescription: "Hocus Pocus"
            )
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        self.statusItem = item

        // Side panel
        self.sidePanelController = SidePanelController()

        // Window polling (event-driven with 10Hz fallback)
        let poller = WindowPoller(appState: appState)
        self.windowPoller = poller
        poller.start()

        // Overlay manager
        let manager = OverlayManager(appState: appState, poller: poller)
        self.overlayManager = manager
        manager.createOverlays()

        // Global hotkeys
        let hotkeys = HotkeyManager()
        self.hotkeyManager = hotkeys
        hotkeys.registerDefaults(
            toggle: { appState.toggle() },
            cycleMode: { appState.cycleMode() },
            excludeCurrentApp: { appState.excludedApps.addFrontmostApp() }
        )

        // Shake to toggle
        let shake = ShakeDetector()
        shake.sensitivity = appState.shakeSensitivity
        self.shakeDetector = shake
        shake.start(
            onShake: {
                guard appState.shakeEnabled else { return }
                appState.toggle()
            },
            onPeek: {
                guard appState.shakeEnabled else { return }
                if appState.isEnabled {
                    appState.isEnabled = false
                }
            },
            onPeekEnd: {
                guard appState.shakeEnabled else { return }
                appState.isEnabled = true
            }
        )

        // 15Hz update loop
        let statusItem = self.statusItem
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            MainActor.assumeIsolated {
                manager.update()
                if shake.sensitivity != appState.shakeSensitivity {
                    shake.sensitivity = appState.shakeSensitivity
                }
                // Keep status icon in sync
                if let button = statusItem?.button {
                    let name = appState.isEnabled ? "circle.fill" : "circle.dotted"
                    let img = NSImage(systemSymbolName: name, accessibilityDescription: "Hocus Pocus")
                    if button.image?.name() != img?.name() {
                        button.image = img
                    }
                }
            }
        }

        // URL scheme handler
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        windowPoller?.stop()
        shakeDetector?.stop()
        overlayManager?.removeAllOverlays()
        hotkeyManager?.unregisterAll()
    }

    @objc private func statusItemClicked() {
        sidePanelController?.toggle()
    }

    @objc private func handleURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent reply: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(
            forKeyword: AEKeyword(keyDirectObject)
        )?.stringValue,
        let url = URL(string: urlString)
        else { return }

        URLSchemeHandler.handle(url, appState: AppState.shared)
    }
}
