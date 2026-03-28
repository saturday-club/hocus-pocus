import Foundation
import AppKit

enum FocusMode: String, CaseIterable, Identifiable, Sendable {
    case ambient
    case deep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ambient: "Ambient"
        case .deep: "Deep"
        }
    }

    var icon: String {
        switch self {
        case .ambient: "sun.max.fill"
        case .deep: "moon.fill"
        }
    }
}

struct TintPreset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let color: NSColor

    static let presets: [TintPreset] = [
        TintPreset(id: "blue", name: "Ocean", color: NSColor(srgbRed: 0.2, green: 0.5, blue: 0.9, alpha: 1)),
        TintPreset(id: "purple", name: "Dusk", color: NSColor(srgbRed: 0.5, green: 0.3, blue: 0.8, alpha: 1)),
        TintPreset(id: "green", name: "Forest", color: NSColor(srgbRed: 0.2, green: 0.7, blue: 0.4, alpha: 1)),
        TintPreset(id: "amber", name: "Warm", color: NSColor(srgbRed: 0.9, green: 0.6, blue: 0.2, alpha: 1)),
        TintPreset(id: "red", name: "Rose", color: NSColor(srgbRed: 0.9, green: 0.3, blue: 0.4, alpha: 1)),
        TintPreset(id: "teal", name: "Teal", color: NSColor(srgbRed: 0.2, green: 0.7, blue: 0.7, alpha: 1)),
        TintPreset(id: "system", name: "System", color: NSColor.controlAccentColor),
    ]
}

enum DefaultsKey {
    static let isEnabled = "isOverlayEnabled"
    static let mode = "focusMode"
    static let blurAmount = "blurAmount"
    static let grainIntensity = "grainIntensity"
    static let tintEnabled = "tintEnabled"
    static let tintPresetID = "tintPresetID"
    static let tintRed = "tintRed"
    static let tintGreen = "tintGreen"
    static let tintBlue = "tintBlue"
    static let tintOpacity = "tintOpacity"
    static let grayscaleEnabled = "grayscaleEnabled"
    static let highlightAllAppWindows = "highlightAllAppWindows"
    static let excludedApps = "excludedApps"
    static let shakeEnabled = "shakeEnabled"
    static let shakeSensitivity = "shakeSensitivity"
}

enum DefaultValues {
    static let blurAmount: Double = 0.6
    static let grainIntensity: Double = 0.4
    static let tintOpacity: Double = 0.15
    static let tintPresetID: String = "blue"
    static let shakeSensitivity: Double = 0.5
}

extension UserDefaults {
    func registerAutoFocusDefaults() {
        register(defaults: [
            DefaultsKey.isEnabled: true,
            DefaultsKey.mode: FocusMode.deep.rawValue,
            DefaultsKey.blurAmount: DefaultValues.blurAmount,
            DefaultsKey.grainIntensity: DefaultValues.grainIntensity,
            DefaultsKey.tintEnabled: false,
            DefaultsKey.tintPresetID: DefaultValues.tintPresetID,
            DefaultsKey.tintOpacity: DefaultValues.tintOpacity,
            DefaultsKey.grayscaleEnabled: false,
            DefaultsKey.highlightAllAppWindows: false,
            DefaultsKey.shakeEnabled: true,
            DefaultsKey.shakeSensitivity: DefaultValues.shakeSensitivity,
        ])
    }
}
