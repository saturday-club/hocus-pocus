import SwiftUI

struct SettingsView: View {
    @State private var appState = AppState.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            effectsTab
                .tabItem { Label("Effects", systemImage: "wand.and.stars") }
            excludedAppsTab
                .tabItem { Label("Excluded", systemImage: "xmark.app") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 420, height: 380)
    }

    private var generalTab: some View {
        Form {
            Toggle("Overlay Enabled", isOn: $appState.isEnabled)

            Picker("Focus Mode", selection: $appState.mode) {
                ForEach(FocusMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Highlight All Windows of Active App", isOn: $appState.highlightAllAppWindows)

            Section("About") {
                Text("Hocus Pocus")
                    .font(.headline)
                Text("A focus overlay for macOS")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var effectsTab: some View {
        Form {
            Section("Blur") {
                HStack {
                    Text("Amount")
                    Slider(value: $appState.blurAmount, in: 0...1)
                    Text(String(format: "%.0f%%", appState.blurAmount * 100))
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Grain") {
                HStack {
                    Text("Intensity")
                    Slider(value: $appState.grainIntensity, in: 0...1)
                    Text(String(format: "%.0f%%", appState.grainIntensity * 100))
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section("Tint") {
                Toggle("Enable Tint", isOn: $appState.tintEnabled)
                if appState.tintEnabled {
                    Picker("Preset", selection: $appState.tintPresetID) {
                        ForEach(TintPreset.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    ColorPicker("Custom Color", selection: tintColorBinding)
                    HStack {
                        Text("Opacity")
                        Slider(value: $appState.tintOpacity, in: 0...0.5)
                        Text(String(format: "%.0f%%", appState.tintOpacity * 100))
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }

            Section("Grayscale") {
                Toggle("Enable Grayscale", isOn: $appState.grayscaleEnabled)
            }
        }
        .padding()
    }

    private var excludedAppsTab: some View {
        ExcludedAppsView()
    }

    private var shortcutsTab: some View {
        Form {
            Section("Global Shortcuts") {
                ShortcutRow(label: "Toggle Overlay", keys: "Cmd + Shift + F")
                ShortcutRow(label: "Cycle Mode", keys: "Cmd + Shift + M")
                ShortcutRow(label: "Exclude Current App", keys: "Cmd + Shift + E")
            }

            Section("URL Scheme") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("hocus-pocus://toggle")
                    Text("hocus-pocus://on | off")
                    Text("hocus-pocus://mode/ambient | deep | toggle")
                    Text("hocus-pocus://ignore | unignore")
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var tintColorBinding: Binding<Color> {
        Binding(
            get: { Color(nsColor: appState.tintColor) },
            set: { appState.tintColor = NSColor($0) }
        )
    }
}

struct ShortcutRow: View {
    let label: String
    let keys: String

    var body: some View {
        LabeledContent(label) {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}
