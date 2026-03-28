import AppKit

@MainActor
enum URLSchemeHandler {

    /// Handle a `hocus-pocus://` URL.
    ///
    /// Supported routes:
    ///   - hocus-pocus://toggle
    ///   - hocus-pocus://on
    ///   - hocus-pocus://off
    ///   - hocus-pocus://mode/toggle
    ///   - hocus-pocus://mode/ambient
    ///   - hocus-pocus://mode/deep
    ///   - hocus-pocus://ignore
    ///   - hocus-pocus://unignore
    static func handle(_ url: URL, appState: AppState) {
        guard url.scheme == "hocus-pocus" else { return }

        let command = url.host ?? ""
        let subcommand = url.pathComponents.dropFirst().first ?? ""

        switch command {
        case "toggle":
            appState.toggle()
        case "on":
            appState.isEnabled = true
        case "off":
            appState.isEnabled = false
        case "mode":
            handleModeCommand(subcommand, appState: appState)
        case "ignore":
            appState.excludedApps.addFrontmostApp()
        case "unignore":
            removeFrontmostApp(appState: appState)
        default:
            print("[URLScheme] Unknown command: \(command)")
        }
    }

    private static func handleModeCommand(_ subcommand: String, appState: AppState) {
        switch subcommand {
        case "toggle":
            appState.cycleMode()
        case "ambient":
            appState.mode = .ambient
        case "deep":
            appState.mode = .deep
        default:
            appState.cycleMode()
        }
    }

    private static func removeFrontmostApp(appState: AppState) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }
        appState.excludedApps.remove(bundleID)
    }
}
