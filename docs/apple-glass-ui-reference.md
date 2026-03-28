# Apple Glass UI: Comprehensive Reference

A definitive guide to building glass-like, translucent, and frosted interfaces on macOS and iOS. Covers every API, material, technique, and private method available.

---

## 1. NSVisualEffectView (macOS, AppKit)

The foundation of all glass effects on macOS. Blurs content behind or within a window.

### API

```swift
class NSVisualEffectView: NSView {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State
    var isEmphasized: Bool
    var maskImage: NSImage?
    var interiorBackgroundStyle: NSView.BackgroundStyle { get }
}
```

### Materials (Complete List)

Every material has a different blur radius, tint, and saturation baked in by Apple.

| Material | Value | Visual | macOS | Notes |
|----------|-------|--------|-------|-------|
| `.titlebar` | 3 | Matches window titlebar | 10.10+ | Adapts to window active state |
| `.selection` | 4 | Selection highlight | 10.10+ | Used in table/outline views |
| `.menu` | 5 | System menu background | 10.11+ | The standard context menu look |
| `.popover` | 6 | Popover background | 10.11+ | Slightly darker than menu |
| `.sidebar` | 7 | Sidebar background | 10.11+ | Lighter, adapts to wallpaper |
| `.headerView` | 10 | Table header | 10.14+ | Very subtle |
| `.sheet` | 11 | Sheet background | 10.14+ | Modal depth feel |
| `.windowBackground` | 12 | Window background | 10.14+ | Base window material |
| `.hudWindow` | 13 | HUD window | 10.14+ | Dark, high contrast |
| `.fullScreenUI` | 15 | Fullscreen overlay | 10.14+ | Medium dark, used by system |
| `.toolTip` | 17 | Tooltip background | 10.14+ | Small element material |
| `.contentBackground` | 18 | Content area | 10.14+ | Light, neutral |
| `.underWindowBackground` | 21 | Behind window | 10.14+ | Desktop-blending |
| `.underPageBackground` | 22 | Behind page content | 10.14+ | Subtle depth |

### Blending Modes

```swift
enum BlendingMode: Int {
    case behindWindow = 0  // Blurs desktop/content BEHIND the window
    case withinWindow = 1  // Blurs content WITHIN the same window hierarchy
}
```

- `.behindWindow`: The overlay effect. Captures and blurs whatever is behind the window on screen. Used for full-screen overlays, transparent sidebars.
- `.withinWindow`: Blurs sibling views within the same window. Used for cards floating inside a panel, frosted sections within a settings window.

### State

```swift
enum State: Int {
    case followsWindowActiveState = 0  // Blur active when window is key
    case active = 1                     // Always blurred
    case inactive = 2                   // Never blurred
}
```

Use `.active` for overlays that must always be blurred regardless of window focus.

### Subclassing

```swift
class CustomBlurView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Access layer tree here to inject custom CAFilter
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Re-apply custom filters after system resets them
    }
}
```

---

## 2. SwiftUI Materials

Available on macOS 12+ / iOS 15+.

### API

```swift
.background(.ultraThinMaterial)
.background(.thinMaterial)
.background(.regularMaterial)
.background(.thickMaterial)
.background(.ultraThickMaterial)
```

### Material Hierarchy

| Material | Blur Level | Transparency | Best For |
|----------|-----------|-------------|---------|
| `.ultraThinMaterial` | Very light | ~10% opaque | Subtle overlays, barely-there frost |
| `.thinMaterial` | Light | ~20% opaque | Light frosted cards |
| `.regularMaterial` | Medium | ~40% opaque | General purpose glass |
| `.thickMaterial` | Strong | ~60% opaque | More opaque sections |
| `.ultraThickMaterial` | Very strong | ~80% opaque | Nearly solid, subtle blur |

### SwiftUI vs AppKit

SwiftUI materials map to NSVisualEffectView internally but with differences:
- SwiftUI materials auto-adapt to light/dark mode
- SwiftUI materials cannot be customized beyond the 5 presets
- For custom blur radius or material behavior, wrap NSVisualEffectView via `NSViewRepresentable`

---

## 3. Liquid Glass (macOS 26 / iOS 26)

Apple's 2025 design language. Only available on macOS Tahoe (26) and iOS 26.

### API

```swift
// Basic glass effect
view.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

// Tinted glass
view.glassEffect(.regular.tint(.blue), in: Circle())

// Interactive glass (responds to hover/press)
view.glassEffect(.regular.interactive, in: Capsule())

// Glass grouping (connected glass elements)
HStack {
    button1.glassEffect(.regular, in: .capsule)
    button2.glassEffect(.regular, in: .capsule)
}
.glassEffectGroup()
```

### Glass Variants

```swift
enum Glass {
    static let regular: Glass     // Standard frosted glass
    static let clear: Glass       // Minimal tint, more transparent
}
```

### Tinting

```swift
glass.tint(_ color: Color)           // Add color tint to glass
glass.tint(_ color: Color, isEnabled: Bool)  // Conditional tint
```

### Shapes

```swift
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
.glassEffect(.regular, in: Circle())
.glassEffect(.regular, in: Capsule())
.glassEffect(.regular, in: .automatic)  // System decides shape
```

### Backward Compatibility

```swift
if #available(macOS 26, *) {
    content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
} else {
    content
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

---

## 4. CAFilter (Private API)

The mechanism Monocle uses for uncapped blur radius. Not documented by Apple but stable across macOS versions.

### Creating a CAFilter

```swift
// CAFilter is a private class -- access via NSClassFromString
guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
      let filter = filterClass.perform(
          NSSelectorFromString("filterWithType:"),
          with: "gaussianBlur"
      )?.takeUnretainedValue() as? NSObject
else { return }

filter.setValue(NSNumber(value: 30.0), forKey: "inputRadius")
```

### Available Filter Types

| Type | Purpose | Key Parameters |
|------|---------|---------------|
| `gaussianBlur` | Gaussian blur | `inputRadius` (CGFloat) |
| `variableBlur` | Variable/gradient blur | `inputRadius`, `inputMaskImage` |
| `colorSaturate` | Saturation control | `inputAmount` (0 = grayscale, 1 = normal) |
| `colorBrightness` | Brightness | `inputAmount` |
| `colorContrast` | Contrast | `inputAmount` |

### Injecting into NSVisualEffectView

NSVisualEffectView creates a private layer hierarchy internally. To find and modify the blur filter:

```swift
func applyCustomBlur(_ layer: CALayer, radius: CGFloat) {
    // Check .filters
    if let filters = layer.filters {
        for case let filter as NSObject in filters {
            if (filter as AnyObject).value(forKey: "inputRadius") as? NSNumber != nil {
                filter.setValue(NSNumber(value: Float(radius)), forKey: "inputRadius")
            }
        }
    }
    // Check .backgroundFilters
    if let bgFilters = layer.backgroundFilters {
        for case let filter as NSObject in bgFilters {
            if (filter as AnyObject).value(forKey: "inputRadius") as? NSNumber != nil {
                filter.setValue(NSNumber(value: Float(radius)), forKey: "inputRadius")
            }
        }
    }
    // Recurse
    for sublayer in layer.sublayers ?? [] {
        applyCustomBlur(sublayer, radius: radius)
    }
}
```

### Persistence via KVO

The system resets filters on appearance changes. Observe sublayer changes to re-apply:

```swift
rootLayer.addObserver(self, forKeyPath: "sublayers", options: [.new], context: nil)

override func observeValue(forKeyPath keyPath: String?, ...) {
    if keyPath == "sublayers" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyCustomBlur(self.layer!, radius: self.customRadius)
        }
    }
}
```

---

## 5. CABackdropLayer (Private)

The private `CALayer` subclass that actually performs the blur. Lives inside NSVisualEffectView's layer tree.

### Accessing It

```swift
// Walk NSVisualEffectView.layer.sublayers recursively
// Look for a layer whose className contains "Backdrop"
func findBackdropLayer(_ layer: CALayer) -> CALayer? {
    if String(describing: type(of: layer)).contains("Backdrop") {
        return layer
    }
    for sublayer in layer.sublayers ?? [] {
        if let found = findBackdropLayer(sublayer) { return found }
    }
    return nil
}
```

### Monocle's Approach

Monocle stores references to the backdrop layer in `observedBackdrop` and `observedRootLayer` ivars, then KVO-observes them to re-apply custom filters whenever the system modifies the layer tree.

---

## 6. compositingFilter on CALayer

Apply CIFilter blend modes to layers for compositing effects.

### API

```swift
layer.compositingFilter = "overlayBlendMode"
// or
layer.compositingFilter = CIFilter(name: "CIOverlayBlendMode")
```

### Available Blend Modes (as strings)

| Filter String | Effect |
|--------------|--------|
| `"multiplyBlendMode"` | Darkens -- multiplies pixel values |
| `"screenBlendMode"` | Lightens -- inverse multiply |
| `"overlayBlendMode"` | Mix: darkens darks, lightens lights |
| `"softLightBlendMode"` | Gentle overlay -- less contrast |
| `"hardLightBlendMode"` | Strong overlay |
| `"differenceBlendMode"` | Absolute difference |
| `"exclusionBlendMode"` | Similar to difference, lower contrast |
| `"colorDodgeBlendMode"` | Brightens underlying by reflecting |
| `"colorBurnBlendMode"` | Darkens underlying by reflecting |
| `"linearDodgeBlendMode"` | Additive brightening |
| `"linearBurnBlendMode"` | Additive darkening |
| `"darkenBlendMode"` | Takes darker pixel |
| `"lightenBlendMode"` | Takes lighter pixel |
| `"hueBlendMode"` | Applies hue of layer to underlying |
| `"saturationBlendMode"` | Applies saturation |
| `"colorBlendMode"` | Applies hue + saturation |
| `"luminosityBlendMode"` | Applies luminosity |

### Use Case: Grain Overlay

```swift
// Grain layer outputs gray noise (0-1) at full opacity
// Overlay blend: gray > 0.5 lightens, < 0.5 darkens
grainMetalLayer.compositingFilter = "overlayBlendMode"
grainMetalLayer.opacity = 0.3  // Controls grain strength
```

---

## 7. CALayer .filters (CIFilter Array)

Apply CIFilters directly to a layer's rendering.

### Desaturation (Grayscale)

```swift
let satFilter = CIFilter(name: "CIColorControls", parameters: [
    "inputSaturation": 0.0  // 0 = grayscale, 1 = normal
])!
satFilter.name = "grayscale"
layer.filters = [satFilter]
```

### Blur (via CIFilter, not CAFilter)

```swift
let blurFilter = CIFilter(name: "CIGaussianBlur", parameters: [
    "inputRadius": 10.0
])!
blurFilter.name = "blur"
layer.backgroundFilters = [blurFilter]
```

---

## 8. MenuBarExtra Styling

### .menu vs .window

```swift
// Simple dropdown menu (limited controls)
MenuBarExtra { ... }.menuBarExtraStyle(.menu)

// Custom window panel (full SwiftUI, sliders, etc.)
MenuBarExtra { ... }.menuBarExtraStyle(.window)
```

### Making .window Transparent

The `.window` style creates an NSPanel with system chrome. To strip it:

1. Add a view that finds its hosting NSWindow
2. Set `window.backgroundColor = .clear` and `window.isOpaque = false`
3. Hide all `NSVisualEffectView` instances with `.behindWindow` blending
4. Re-apply on every `didBecomeKeyNotification` (system re-adds chrome)

See `docs/ui-learnings.md` for complete implementation.

---

## 9. NSPanel for Custom Panels

If MenuBarExtra chrome stripping is insufficient, build a fully custom panel:

```swift
let panel = NSPanel(
    contentRect: .init(x: 0, y: 0, width: 340, height: 500),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: true
)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.level = .popUpMenu
panel.hasShadow = true
panel.hidesOnDeactivate = true
panel.collectionBehavior = [.canJoinAllSpaces, .transient]
panel.contentView = NSHostingView(rootView: YourSwiftUIPanel())
```

Caveats: requires inheriting from NSObject for `#selector` target/action, and the SwiftUI MenuBarExtra will steal clicks if both are present.

---

## 10. Dark Mode / Light Mode

### Automatic Adaptation

All `NSVisualEffectView.Material` values automatically adapt to the system appearance. SwiftUI materials do the same.

### Manual Detection

```swift
// In NSView
override func viewDidChangeEffectiveAppearance() {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
}

// In SwiftUI
@Environment(\.colorScheme) var colorScheme
```

### Forcing Appearance

```swift
// Force dark mode on a view
view.appearance = NSAppearance(named: .darkAqua)

// SwiftUI
content.preferredColorScheme(.dark)
```

---

## 11. Performance

### GPU Cost by Feature

| Feature | GPU Cost | Notes |
|---------|---------|-------|
| NSVisualEffectView (behindWindow) | 2-5% | Full-screen blur is expensive |
| NSVisualEffectView (withinWindow) | 0.5-1% | Only blurs view content |
| CAFilter gaussianBlur (high radius) | 3-8% | Scales with radius squared |
| Metal grain (static, once) | ~0% | Single render, no ongoing cost |
| Metal grain (animated, 30fps) | 2-5% | Per-frame GPU dispatch |
| compositingFilter overlay | ~0.1% | Hardware-accelerated blend |
| CIFilter on layer | 0.5-2% | Depends on filter complexity |

### Optimization Tips

1. Use `.withinWindow` instead of `.behindWindow` where possible (much cheaper)
2. Render grain statically -- don't animate if not needed
3. Use half or quarter resolution for grain textures
4. Limit CAFilter radius to 50pt max (diminishing returns beyond that)
5. Avoid stacking multiple NSVisualEffectViews
6. Use `state = .active` to prevent blur cycling with window focus

---

## 12. Apple HIG Guidelines

### When to Use Glass

- Window sidebars and toolbars
- Floating panels and popovers
- Menu bar dropdowns
- Cards and sections within settings
- Overlay controls on media content

### When NOT to Use Glass

- Primary content areas (text, images, data)
- Backgrounds that need high contrast for readability
- Small UI elements where blur is imperceptible
- Performance-critical real-time rendering views

### Depth Hierarchy

Apple recommends a 3-level depth system:
1. **Base**: Window background (`.windowBackground` material)
2. **Elevated**: Cards and sections (`.sidebar` or `.regularMaterial`)
3. **Prominent**: Active controls, selections (solid color or `.thickMaterial`)

### Liquid Glass Principles (macOS 26+)

- Glass is dynamic -- it reflects and refracts the content behind it
- Use `.glassEffect()` for interactive elements (buttons, tabs)
- Group related glass elements with `.glassEffectGroup()`
- Avoid placing glass on glass (visual noise)
- Tint glass to match your app's accent color subtly

---

## 13. Complete Example: Monocle-Style Panel

```swift
struct FloatingGlassPanel: View {
    var body: some View {
        VStack(spacing: 10) {
            GlassCard {
                HStack {
                    Image(systemName: "app.fill")
                        .frame(width: 32, height: 32)
                    Text("Your App")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                }
                .padding(14)
            }

            GlassCard {
                VStack(spacing: 20) {
                    SliderRow(icon: "drop.fill", label: "Blur", value: .constant(0.7), color: .blue)
                    SliderRow(icon: "circle.fill", label: "Tint", value: .constant(0.3), color: .purple)
                }
                .padding(16)
            }
        }
        .padding(14)
        .frame(width: 340)
        .background(PanelChromeStripper())
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

This produces Monocle-style frosted glass cards floating on a transparent panel background with no visible borders or system chrome.
