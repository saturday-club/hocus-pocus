import SwiftUI

@main
struct HocusPocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .onAppear { stripWindowChrome() }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                    stripWindowChrome()
                }
        } label: {
            Image(systemName: appState.isEnabled ? "circle.fill" : "circle.dotted")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private func stripWindowChrome() {
        // Find the MenuBarExtra window and nuke its background
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for window in NSApp.windows {
                // MenuBarExtra windows are NSPanel subclasses at popUpMenu level
                guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue - 5 else { continue }
                guard window.className.contains("MenuBarExtra")
                    || window.className.contains("StatusBarWindow")
                    || window.className.contains("NSPanel")
                    || window.className.contains("NSStatusBar")
                    || (window.frame.width > 300 && window.frame.width < 400 && window.frame.height > 200)
                else { continue }

                window.isOpaque = false
                window.backgroundColor = .clear

                // Nuclear: hide every NSVisualEffectView in the entire window
                if let contentView = window.contentView {
                    nukeAllEffectViews(contentView)
                }
            }
        }
    }

    private func nukeAllEffectViews(_ view: NSView) {
        if let effectView = view as? NSVisualEffectView {
            // Check if this is our GlassCard's VisualEffectBlur by checking blendingMode
            // Our cards use .withinWindow, system chrome uses .behindWindow
            if effectView.blendingMode == .behindWindow {
                effectView.isHidden = true
            }
        }

        for subview in view.subviews {
            nukeAllEffectViews(subview)
        }
    }
}
