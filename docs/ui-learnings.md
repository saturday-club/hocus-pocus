# UI Learnings: Building Glass-Like Interfaces on macOS

Everything we learned building the Hocus Pocus menu bar panel, distilled into actionable patterns.

## The Core Problem

macOS MenuBarExtra (`.window` style) wraps your SwiftUI content in a system-provided NSPanel with opaque chrome -- a dark background, rounded corners, and visual effect views. To achieve Monocle's fully transparent floating-cards look, you must strip this chrome at runtime.

## Chrome Stripping

The system adds `NSVisualEffectView` instances with `.behindWindow` blending mode as the panel background. To remove them:

```swift
// Hook into window appearance
.onAppear { stripWindowChrome() }
.onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
    stripWindowChrome()
}

func stripWindowChrome() {
    for window in NSApp.windows {
        guard window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue - 5 else { continue }
        window.isOpaque = false
        window.backgroundColor = .clear
        if let contentView = window.contentView {
            nukeSystemEffectViews(contentView)
        }
    }
}

func nukeSystemEffectViews(_ view: NSView) {
    if let effectView = view as? NSVisualEffectView {
        // System chrome uses .behindWindow; our cards use .withinWindow
        if effectView.blendingMode == .behindWindow {
            effectView.isHidden = true
        }
    }
    for subview in view.subviews { nukeSystemEffectViews(subview) }
}
```

Key insight: distinguish system chrome from your own glass views by blending mode. System uses `.behindWindow`, your cards use `.withinWindow`.

## Glass Card Pattern

Each card is an `NSVisualEffectView` wrapped in SwiftUI via `NSViewRepresentable`:

```swift
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

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                    Color.white.opacity(0.06)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
```

## Material Selection

We tested every NSVisualEffectView material. Results on dark backgrounds:

| Material | Appearance | Use For |
|----------|-----------|---------|
| `.sidebar` | Light, translucent, adapts to wallpaper | Cards floating on transparent panel |
| `.hudWindow` | Dark, opaque-feeling | Dark mode cards |
| `.popover` | Medium, system popover look | Icon circle backgrounds |
| `.fullScreenUI` | Medium-dark | Full overlay blur |
| `.menu` | System menu background | Avoid (too system-like) |
| `.headerView` | Very subtle | Subtle section headers |
| `.sheet` | Sheet-like depth | Modal-feeling cards |
| `.titlebar` | Titlebar-matched | Window chrome areas |

For Monocle-like transparent panels: use `.sidebar` with `.withinWindow` blending.

## Blending Modes

| Mode | Behavior | When to Use |
|------|----------|-------------|
| `.behindWindow` | Blurs content behind the window | Full-screen overlays (our BlurView) |
| `.withinWindow` | Blurs content within the window hierarchy | Cards inside a panel/popover |

`.behindWindow` is what makes the overlay blur the desktop. `.withinWindow` is what makes cards look frosted within the panel.

## No Borders

Monocle's UI has zero visible borders. The card edges are defined entirely by the material difference between the card and its surroundings. Do not add:
- `.strokeBorder()` overlays
- Box shadows that create visible outlines
- Colored borders

The glass material itself provides enough visual separation.

## Custom Sliders

System SwiftUI Slider on macOS has almost no customization. Build custom:

```swift
struct SliderTrack: View {
    @Binding var value: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Background track
                Capsule().fill(.white.opacity(0.07)).frame(height: 5)

                // Colored fill with gradient
                Capsule()
                    .fill(LinearGradient(
                        colors: [color.opacity(0.5), color],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: max(5, CGFloat(value) * w), height: 5)

                // Dot markers
                HStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { i in
                        Circle().fill(.white.opacity(0.1)).frame(width: 2, height: 2)
                        if i < 9 { Spacer() }
                    }
                }
                .padding(.horizontal, 3)

                // Thumb
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(value) * (w - 16))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                        value = min(1, max(0, drag.location.x / w))
                    })
            }
        }
        .frame(height: 16)
    }
}
```

Key: the dot markers along the track (Monocle has these) give visual reference for slider position.

## Spacing and Sizing

Monocle's UI feels spacious because of generous sizing:

| Element | Monocle Size | Typical macOS |
|---------|-------------|---------------|
| App icon | 32x32 | 16x16 |
| Power button | 56x56 | 28x28 |
| Icon circles | 36x36 | 20x20 |
| Card padding | 14-18px | 8-10px |
| Between cards | 10px | 4-6px |
| Between slider rows | 22px | 8-12px |
| Panel width | 340px | 280px |
| Font (labels) | 13-14pt semibold | 11-12pt regular |

## Things That Did Not Work

1. **SwiftUI `.ultraThinMaterial` as card background** -- looks different from NSVisualEffectView; doesn't adapt as well to wallpaper colors
2. **Blue gradient border strokes** -- looked dated; Monocle uses no borders at all
3. **Custom NSPanel replacing MenuBarExtra** -- `#selector` target/action didn't receive clicks because the SwiftUI MenuBarExtra stole them. Stripping chrome from MenuBarExtra works better
4. **`.background(.clear)` on MenuBarExtra content** -- doesn't affect the hosting window's chrome; you must find and modify the NSWindow directly
5. **Hiding NSVisualEffectView by class name** -- unreliable across macOS versions; distinguish by `.blendingMode` instead

## The Final Architecture

```
MenuBarExtra (.window style)
  |-- PanelChromeStripper (hides system .behindWindow effect views)
  |-- MenuBarPanel (VStack of GlassCards)
       |-- GlassCard (VisualEffectBlur .sidebar .withinWindow + white tint)
       |   |-- Content (buttons, sliders, text)
       |-- GlassCard
       |-- ...
```

Each GlassCard is self-contained: it provides its own frosted glass background via NSVisualEffectView. The panel background is transparent (stripped chrome). Cards float over whatever is behind the panel.
