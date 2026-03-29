import SwiftUI

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content
    @State private var isHovered = false

    init(cornerRadius: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26, *) {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.white.opacity(0.12))
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 4)
                )
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    VisualEffectBlur(material: .underPageBackground, blendingMode: .behindWindow)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        isHovered = hovering
                    }
                }
        }
    }
}

/// NSVisualEffectView wrapper for glass blur inside SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Menu Bar Panel

struct MenuBarPanel: View {
    @State private var appState = AppState.shared

    var body: some View {
        panelContent
            .padding(14)
            .frame(width: 340)
    }

    @ViewBuilder
    private var panelContent: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                VStack(spacing: 10) {
                    topBar
                    effectsCard
                    shakeCard
                    bottomBar
                }
            }
        } else {
            VStack(spacing: 10) {
                topBar
                effectsCard
                shakeCard
                bottomBar
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            GlassCard {
                Button {
                    appState.excludedApps.toggle(appState.frontmostAppBundleID)
                } label: {
                    HStack(spacing: 10) {
                        if let icon = appState.frontmostAppIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 24))
                                .frame(width: 32, height: 32)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(isCurrentAppExcluded ? "Ignored" : "Ignore")
                                .font(.system(size: 14, weight: .semibold))
                            Text(appState.frontmostAppName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: isCurrentAppExcluded ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }

            GlassCard {
                Button {
                    appState.toggle()
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(appState.isEnabled ? .white : .secondary)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
            }
        }
    }


    // MARK: - Effects Card

    private var effectsCard: some View {
        GlassCard(cornerRadius: 16) {
            VStack(spacing: 22) {
                EffectRow(
                    icon: "drop.fill",
                    label: "Blur",
                    value: $appState.blurAmount,
                    color: .blue
                )

                EffectRow(
                    icon: "circle.fill",
                    label: "Tint",
                    value: $appState.tintOpacity,
                    color: tintSwiftUIColor,
                    enabled: $appState.tintEnabled
                )

                EffectRow(
                    icon: "water.waves",
                    label: "Grain",
                    value: $appState.grainIntensity,
                    color: .cyan
                )
            }
            .padding(18)
        }
    }

    // MARK: - Shake Card

    private var shakeCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        appState.shakeEnabled.toggle()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(appState.shakeEnabled ? .blue : .secondary)
                            .frame(width: 36, height: 36)
                            .background(
                                VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                                    .clipShape(Circle())
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shake to toggle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(appState.shakeEnabled ? .primary : .secondary)
                        Text("or hold Shift + Shake to peek")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    SettingsLink {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if appState.shakeEnabled {
                    HStack(spacing: 8) {
                        Text("Sensitivity")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        SliderTrack(value: $appState.shakeSensitivity, color: .blue, trackHeight: 3, thumbSize: 10)

                        Text(sensitivityLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 30)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .animation(.easeOut(duration: 0.2), value: appState.shakeEnabled)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        GlassCard {
            HStack(spacing: 0) {
                Button {
                    appState.grayscaleEnabled.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 18))
                        Text("Mono")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(appState.grayscaleEnabled ? .white : .secondary)
                    .frame(width: 80)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 30)
                    .padding(.horizontal, 4)

                Menu {
                    ForEach(TintPreset.presets) { preset in
                        Button {
                            appState.tintEnabled = true
                            appState.tintPresetID = preset.id
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(nsColor: preset.color))
                                    .frame(width: 10, height: 10)
                                Text(preset.name)
                                if appState.tintPresetID == preset.id && appState.tintEnabled {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("No Tint") { appState.tintEnabled = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "display")
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Auto-hide")
                                .font(.system(size: 11, weight: .medium))
                            Text("Off")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    // MARK: - Helpers

    private var isCurrentAppExcluded: Bool {
        appState.excludedApps.contains(appState.frontmostAppBundleID)
    }

    private var tintSwiftUIColor: Color {
        Color(nsColor: appState.tintColor)
    }

    private var sensitivityLabel: String {
        if appState.shakeSensitivity < 0.35 { return "Low" }
        if appState.shakeSensitivity < 0.65 { return "Mid" }
        return "High"
    }
}

// MARK: - Effect Row

struct EffectRow: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let color: Color
    @Binding var enabled: Bool

    init(icon: String, label: String, value: Binding<Double>, color: Color, enabled: Binding<Bool> = .constant(true)) {
        self.icon = icon; self.label = label; self._value = value; self.color = color; self._enabled = enabled
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 38, alignment: .leading)

            SliderTrack(value: $value, color: color)
        }
    }
}

// MARK: - Slider Track

struct SliderTrack: View {
    @Binding var value: Double
    let color: Color
    var trackHeight: CGFloat = 5
    var thumbSize: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.07))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(trackHeight, CGFloat(value) * w), height: trackHeight)

                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        Circle()
                            .fill(.white.opacity(0.1))
                            .frame(width: 2, height: 2)
                        if i < 9 { Spacer() }
                    }
                }
                .padding(.horizontal, 3)
                .frame(height: trackHeight)

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: CGFloat(value) * (w - thumbSize))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                value = min(1, max(0, drag.location.x / w))
                            }
                    )
            }
            .frame(height: thumbSize)
            .frame(maxHeight: .infinity)
        }
        .frame(height: thumbSize)
    }
}
