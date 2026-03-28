import AppKit
import Observation

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: DefaultsKey.isEnabled) }
    }

    var mode: FocusMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.mode) }
    }

    var blurAmount: Double {
        didSet { UserDefaults.standard.set(blurAmount, forKey: DefaultsKey.blurAmount) }
    }

    var grainIntensity: Double {
        didSet { UserDefaults.standard.set(grainIntensity, forKey: DefaultsKey.grainIntensity) }
    }

    var tintEnabled: Bool {
        didSet { UserDefaults.standard.set(tintEnabled, forKey: DefaultsKey.tintEnabled) }
    }

    var tintPresetID: String {
        didSet {
            UserDefaults.standard.set(tintPresetID, forKey: DefaultsKey.tintPresetID)
            if let preset = TintPreset.presets.first(where: { $0.id == tintPresetID }) {
                tintColor = preset.color
            }
        }
    }

    var tintColor: NSColor {
        didSet {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            tintColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            UserDefaults.standard.set(Double(r), forKey: DefaultsKey.tintRed)
            UserDefaults.standard.set(Double(g), forKey: DefaultsKey.tintGreen)
            UserDefaults.standard.set(Double(b), forKey: DefaultsKey.tintBlue)
        }
    }

    var tintOpacity: Double {
        didSet { UserDefaults.standard.set(tintOpacity, forKey: DefaultsKey.tintOpacity) }
    }

    var grayscaleEnabled: Bool {
        didSet { UserDefaults.standard.set(grayscaleEnabled, forKey: DefaultsKey.grayscaleEnabled) }
    }

    var highlightAllAppWindows: Bool {
        didSet { UserDefaults.standard.set(highlightAllAppWindows, forKey: DefaultsKey.highlightAllAppWindows) }
    }

    var shakeEnabled: Bool {
        didSet { UserDefaults.standard.set(shakeEnabled, forKey: DefaultsKey.shakeEnabled) }
    }

    var shakeSensitivity: Double {
        didSet { UserDefaults.standard.set(shakeSensitivity, forKey: DefaultsKey.shakeSensitivity) }
    }

    let excludedApps: ExcludedAppsStore

    // Derived: current frontmost app info for UI
    var frontmostAppName: String = ""
    var frontmostAppBundleID: String = ""
    var frontmostAppIcon: NSImage?

    private init() {
        UserDefaults.standard.registerHocusPocusDefaults()
        let ud = UserDefaults.standard
        self.isEnabled = ud.bool(forKey: DefaultsKey.isEnabled)
        let modeRaw = ud.string(forKey: DefaultsKey.mode) ?? FocusMode.deep.rawValue
        self.mode = FocusMode(rawValue: modeRaw) ?? .deep
        self.blurAmount = ud.double(forKey: DefaultsKey.blurAmount)
        self.grainIntensity = ud.double(forKey: DefaultsKey.grainIntensity)
        self.tintEnabled = ud.bool(forKey: DefaultsKey.tintEnabled)
        let storedPresetID = ud.string(forKey: DefaultsKey.tintPresetID) ?? DefaultValues.tintPresetID
        self.tintPresetID = storedPresetID
        let r = ud.double(forKey: DefaultsKey.tintRed)
        let g = ud.double(forKey: DefaultsKey.tintGreen)
        let b = ud.double(forKey: DefaultsKey.tintBlue)
        if r == 0 && g == 0 && b == 0,
           let preset = TintPreset.presets.first(where: { $0.id == storedPresetID }) {
            self.tintColor = preset.color
        } else {
            self.tintColor = NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        }
        self.tintOpacity = ud.double(forKey: DefaultsKey.tintOpacity)
        self.grayscaleEnabled = ud.bool(forKey: DefaultsKey.grayscaleEnabled)
        self.highlightAllAppWindows = ud.bool(forKey: DefaultsKey.highlightAllAppWindows)
        self.shakeEnabled = ud.object(forKey: DefaultsKey.shakeEnabled) == nil ? true : ud.bool(forKey: DefaultsKey.shakeEnabled)
        self.shakeSensitivity = ud.double(forKey: DefaultsKey.shakeSensitivity)
        self.excludedApps = ExcludedAppsStore()

        // Start frontmost app tracking (after all properties initialized)
        startFrontmostAppTracking()
    }

    func toggle() {
        isEnabled.toggle()
    }

    func cycleMode() {
        mode = (mode == .deep) ? .ambient : .deep
    }

    private func startFrontmostAppTracking() {
        updateFrontmostApp()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateFrontmostApp()
            }
        }
    }

    private func updateFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        frontmostAppName = app.localizedName ?? "Unknown"
        frontmostAppBundleID = app.bundleIdentifier ?? ""
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: frontmostAppBundleID) {
            frontmostAppIcon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            frontmostAppIcon = app.icon
        }
    }
}
