# Definitive Reference: Glass-Like Application Interfaces on Apple Platforms

> Comprehensive API reference for building translucent, blurred, and glass-effect UIs on macOS and iOS.
> Covers AppKit, UIKit, SwiftUI, Core Animation private APIs, and Liquid Glass (macOS 26 / iOS 26).

---

## Table of Contents

1. [NSVisualEffectView (macOS AppKit)](#1-nsvisualeffectview-macos-appkit)
2. [SwiftUI Materials](#2-swiftui-materials)
3. [Liquid Glass (macOS 26 / iOS 26)](#3-liquid-glass-macos-26--ios-26)
4. [CAFilter Private API](#4-cafilter-private-api)
5. [CABackdropLayer](#5-cabackdroplayer)
6. [compositingFilter on CALayer](#6-compositingfilter-on-calayer)
7. [SwiftUI Background Modifiers](#7-swiftui-background-modifiers)
8. [MenuBarExtra Styling](#8-menubareextra-styling)
9. [NSPanel and Transparent Windows](#9-nspanel-and-transparent-windows)
10. [NSWindow Style Masks and Titlebar](#10-nswindow-style-masks-and-titlebar)
11. [Dark Mode / Light Mode and Vibrancy](#11-dark-mode--light-mode-and-vibrancy)
12. [Performance Considerations](#12-performance-considerations)
13. [Apple HIG Best Practices](#13-apple-hig-best-practices)

---

## 1. NSVisualEffectView (macOS AppKit)

**Class:** `NSVisualEffectView` (AppKit)
**Availability:** macOS 10.10+
**Purpose:** Adds translucency and vibrancy effects to views. Blurs content either behind the window or within it.

### 1.1 API Signature

```swift
class NSVisualEffectView: NSView {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State
    var maskImage: NSImage?
    var isEmphasized: Bool
    var interiorBackgroundStyle: NSView.BackgroundStyle { get }
}
```

### 1.2 Materials (NSVisualEffectView.Material)

Each material defines a specific combination of blur radius, saturation, tint color, and blend mode optimized for a particular UI context. Apple recommends selecting materials by **semantic purpose**, not visual appearance.

| Material | Raw Value | Description | Availability |
|----------|-----------|-------------|--------------|
| `.titlebar` | 3 | Window titlebar area | macOS 10.10+ |
| `.selection` | 4 | Selected content in key window | macOS 10.10+ |
| `.menu` | 5 | Menu backgrounds | macOS 10.11+ |
| `.popover` | 6 | Popover window backgrounds | macOS 10.11+ |
| `.sidebar` | 7 | Source list / sidebar backgrounds | macOS 10.11+ |
| `.headerView` | 10 | Table/outline header views | macOS 10.14+ |
| `.sheet` | 11 | Sheet window backgrounds | macOS 10.14+ |
| `.windowBackground` | 12 | General window background | macOS 10.14+ |
| `.hudWindow` | 13 | HUD window backgrounds | macOS 10.14+ |
| `.fullScreenUI` | 15 | Full-screen presentation UI | macOS 10.14+ |
| `.toolTip` | 17 | Tooltip backgrounds | macOS 10.14+ |
| `.contentBackground` | 18 | Content area backgrounds | macOS 10.14+ |
| `.underWindowBackground` | 21 | Background behind window | macOS 10.14+ |
| `.underPageBackground` | 22 | Background behind scrolled page content | macOS 10.14+ |

**Deprecated materials (macOS 10.14+):**

| Material | Raw Value | Replacement |
|----------|-----------|-------------|
| `.appearanceBased` | 0 | Use a semantic material |
| `.light` | 1 | Use a semantic material |
| `.dark` | 2 | Use a semantic material |
| `.mediumLight` | 8 | Use a semantic material |
| `.ultraDark` | 9 | Use a semantic material |

### 1.3 Blending Modes (NSVisualEffectView.BlendingMode)

```swift
enum BlendingMode: Int {
    case behindWindow = 0   // Blurs content behind the entire window (desktop, other apps)
    case withinWindow = 1   // Blurs content behind the view within the same window only
}
```

**Visual difference:**
- `.behindWindow`: The view samples and blurs everything behind the window (desktop wallpaper, other windows). Used for window chrome, sidebars, toolbars.
- `.withinWindow`: The view samples and blurs only sibling content within the same window. Used for in-content overlays, selection highlights, inline controls.

**Performance:** `.withinWindow` is cheaper because it only composites within the window's own layer tree. `.behindWindow` requires WindowServer involvement.

### 1.4 State (NSVisualEffectView.State)

```swift
enum State: Int {
    case followsWindowActiveState = 0  // DEFAULT: Active when window is key, inactive otherwise
    case active = 1                     // Always renders the visual effect
    case inactive = 2                   // Never renders the effect (plain view)
}
```

Use `.active` to keep the blur visible even when the window is not key (useful for floating panels, HUDs).

### 1.5 Additional Properties

```swift
// Mask the material's alpha channel with an image
// Use smallest possible image + capInsets for stretching
visualEffect.maskImage = NSImage(named: "roundedMask")

// Whether the material renders in its emphasized state
// Automatically set when the view or a descendant becomes first responder
visualEffect.isEmphasized = true

// Read-only: tells subviews whether to use light or dark content
let style = visualEffect.interiorBackgroundStyle  // .light or .dark
```

### 1.6 SwiftUI Wrapper (NSViewRepresentable)

```swift
import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let state: NSVisualEffectView.State

    init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// Usage:
struct ContentView: View {
    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            Text("Translucent HUD")
                .foregroundColor(.white)
        }
    }
}
```

### 1.7 Subclassing

When subclassing NSVisualEffectView, you MUST call `super` for overridden methods. Key override points:

```swift
class CustomVisualEffectView: NSVisualEffectView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        // Customize layer properties here
        layer?.cornerRadius = 12
    }

    // React to appearance changes
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Update custom tint overlays, etc.
    }
}
```

### 1.8 Internal Layer Hierarchy

NSVisualEffectView internally constructs:

```
NSVisualEffectView.layer (CALayer - container)
  +-- CABackdropLayer (performs actual blur + saturation)
  |     filters: [gaussianBlur, colorSaturate]
  +-- CALayer (tint overlay with blend mode)
  +-- CALayer (noise texture, subtle grain)
```

This hierarchy is private but can be inspected and manipulated (see Section 4 and 5).

---

## 2. SwiftUI Materials

**Availability:** iOS 15+ / macOS 12+
**Purpose:** First-class translucent blur backgrounds in SwiftUI without dropping to AppKit/UIKit.

### 2.1 Material Types (thinnest to thickest)

| Material | Description | Translucency | When to Use |
|----------|-------------|--------------|-------------|
| `.ultraThinMaterial` | Mostly translucent | ~90% transparent | Overlays on rich media, subtle tints |
| `.thinMaterial` | More translucent than opaque | ~75% transparent | Light overlays, secondary panels |
| `.regularMaterial` | Balanced translucency | ~50% transparent | General-purpose backgrounds |
| `.thickMaterial` | More opaque than translucent | ~30% transparent | Prominent panels needing readability |
| `.ultraThickMaterial` | Nearly opaque | ~15% transparent | Maximum readability, minimal show-through |
| `.bar` | Matches system toolbar style | System-defined | Toolbars, tab bars, navigation bars |

### 2.2 API Usage

```swift
// As a background
Text("Hello, World!")
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))

// As a background with shape
Text("Frosted Card")
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

// With overlay
Image("landscape")
    .overlay {
        VStack {
            Text("Caption")
        }
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }
```

### 2.3 How Materials Render

Each material internally applies:
1. A Gaussian blur to sampled background content
2. Color saturation adjustment
3. A tint layer (adapts to light/dark mode)
4. Optional noise texture for depth

Thinner materials use lower blur radii and more transparent tints.
Thicker materials use higher blur radii and more opaque tints.

All materials automatically adapt to:
- Light mode vs. dark mode
- High contrast accessibility settings
- Reduced transparency accessibility settings (falls back to solid color)

### 2.4 Compatibility

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 10.0+ / visionOS 1.0+
- On macOS, materials map to NSVisualEffectView materials internally
- With "Reduce transparency" enabled, materials degrade to opaque backgrounds

---

## 3. Liquid Glass (macOS 26 / iOS 26)

**Availability:** iOS 26 / macOS 26 (Tahoe) / iPadOS 26 / watchOS 26 / tvOS 26 / visionOS 26
**Announced:** WWDC 2025 (June 9, 2025)
**Purpose:** Apple's most significant visual design evolution since iOS 7. Translucent, dynamic material that reflects and refracts surrounding content.

### 3.1 Core Concept: Lensing, Not Blurring

Liquid Glass uses **lensing** -- bending and concentrating light rather than scattering it. This creates:
- Real-time light refraction through the glass surface
- Specular highlights responding to device motion (gyroscope)
- Adaptive shadows that ground glass elements
- Interactive behaviors (scaling, bouncing, shimmering on touch)

### 3.2 The glassEffect Modifier (SwiftUI)

```swift
// Full signature
func glassEffect<S: Shape>(
    _ glass: Glass = .regular,
    in shape: S = .capsule,
    isEnabled: Bool = true
) -> some View
```

**Basic usage:**

```swift
// Default: regular glass in capsule shape
Text("Glass Button")
    .padding()
    .glassEffect()

// Explicit variant and shape
Text("Settings")
    .padding()
    .glassEffect(.regular, in: .capsule)

// Circle shape
Image(systemName: "gear")
    .padding()
    .glassEffect(.regular, in: .circle)

// Rounded rectangle with container-concentric corners
Text("Card")
    .padding()
    .glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))

// Custom corner radius
Text("Panel")
    .padding()
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
```

### 3.3 Glass Variants

| Variant | Description | Visual | When to Use |
|---------|-------------|--------|-------------|
| `.regular` | Default frosted glass | Moderate refraction, good legibility | Primary controls, navigation elements |
| `.clear` | More transparent | Higher refraction, less frosting | Over media-rich content with bold foreground |
| `.identity` | No glass effect | Transparent pass-through | Conditionally disable glass (animations) |

**Important:** Do NOT mix `.regular` and `.clear` within the same control group.

### 3.4 Tinting

```swift
// Solid color tint
.glassEffect(.regular.tint(.blue))

// Tint with opacity
.glassEffect(.regular.tint(.purple.opacity(0.6)))

// Semantic tinting
.glassEffect(.regular.tint(.accentColor))
```

### 3.5 Interactive Behaviors

```swift
// Enable interactive glass (scale + shimmer on touch)
Button("Tap Me") { }
    .glassEffect(.regular.tint(.orange).interactive())

// Interactive behaviors include:
// - Scale up on press
// - Bounce on release
// - Shimmer/illumination from touch point
// - Specular highlight shift
```

### 3.6 GlassEffectContainer

Groups multiple glass elements for consistent rendering. Glass cannot sample other glass, so nearby glass elements in different containers produce inconsistent results.

```swift
GlassEffectContainer {
    HStack(spacing: 16) {
        Button("Edit") { }
            .glassEffect()
        Button("Share") { }
            .glassEffect()
        Button("Delete") { }
            .glassEffect()
    }
}

// With spacing threshold for morphing
GlassEffectContainer(spacing: 8) {
    // Elements closer than 8pt will visually blend/morph together
    HStack(spacing: 4) {
        ForEach(items) { item in
            ItemView(item)
                .glassEffect()
                .glassEffectID(item.id)  // Enable morphing transitions
        }
    }
}
```

**Key rules:**
- Glass elements in the same container share their sampling region
- The `spacing` parameter controls the morphing threshold
- Use `glassEffectID()` for smooth morphing transitions between states
- Elements closer than the spacing threshold visually merge like water droplets

### 3.7 Concentric Corner Radius

```swift
// Automatically match container's corner curvature
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))

// ConcentricRectangle shape (iOS 26)
ConcentricRectangle()  // Inner corners concentrically aligned with outer container
```

Concentric corners ensure inner rounded rectangles share the same center of curvature as their outer container, creating a visually harmonious nested appearance.

### 3.8 Button Styles

```swift
// Glass button style
Button("Action") { }
    .buttonStyle(.glass)

// Prominent glass button (with background fill)
Button("Primary Action") { }
    .buttonStyle(.glassProminent)
```

### 3.9 UIKit Integration (iOS 26)

```swift
// UIGlassEffect - describes the style
let glassEffect = UIGlassEffect()  // .regular by default

// UIGlassEffectView - renders the effect
let glassView = UIVisualEffectView(effect: glassEffect)
glassView.contentView.addSubview(myContentView)

// UIGlassEffectContainerView - groups multiple glass views
let container = UIGlassEffectContainerView()
container.addSubview(glassView1)
container.addSubview(glassView2)
```

### 3.10 AppKit Integration (macOS 26 Tahoe)

```swift
// NSGlassEffectView - primary class for Liquid Glass in AppKit
let glassView = NSGlassEffectView()
glassView.contentView = myContentView  // AppKit applies glass treatments

// NSGlassEffectContainerView - groups multiple glass elements
let container = NSGlassEffectContainerView()
container.addSubview(glassView1)
container.addSubview(glassView2)
```

**Migration note:** If you are using NSVisualEffectView to display material inside a sidebar, it will prevent the glass material from showing through on macOS 26. Consider migrating to NSGlassEffectView.

### 3.11 Design Rules

1. Liquid Glass is exclusively for the **navigation layer** that floats above app content
2. Never apply glass to content itself (lists, tables, media, text bodies)
3. Content sits at the bottom layer; glass controls float on top
4. Keep depth <= 20 for UI controls
5. Frost values of 10--25 are recommended for accessible translucency
6. Test with "Reduce Transparency" accessibility setting

---

## 4. CAFilter Private API

**Status:** Private API (not in public headers). App Store risk.
**Location:** QuartzCore framework (CoreAnimation)
**Purpose:** Low-level filters applied to CALayer trees. The building blocks behind NSVisualEffectView/UIVisualEffectView.

### 4.1 Creating Filters

```objc
// Objective-C (bridging header required for Swift)
@interface CAFilter : NSObject
+ (instancetype)filterWithType:(NSString *)type;
@property (copy) NSString *name;
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath;
@end
```

```swift
// Swift usage (requires bridging header or @objc runtime)
let blurFilter = CAFilter(type: kCAFilterGaussianBlur)
blurFilter.setValue(30.0, forKeyPath: "inputRadius")
blurFilter.setValue(true, forKeyPath: "inputNormalizeEdges")

let saturateFilter = CAFilter(type: kCAFilterColorSaturate)
saturateFilter.setValue(1.8, forKeyPath: "inputAmount")
```

### 4.2 Complete Filter Type Constants

From the private header (`CoreAnimationPrivate/CAFilter.h`):

**Image Processing Filters:**

| Constant | Purpose | Key Parameters |
|----------|---------|----------------|
| `kCAFilterGaussianBlur` | Gaussian blur | `inputRadius` (Float), `inputNormalizeEdges` (Bool) |
| `kCAFilterColorSaturate` | Saturation adjustment | `inputAmount` (Float, 0.0 = grayscale, 1.0 = normal, >1.0 = oversaturated) |
| `kCAFilterColorBrightness` | Brightness adjustment | `inputAmount` (Float) |
| `kCAFilterColorContrast` | Contrast adjustment | `inputAmount` (Float) |
| `kCAFilterColorInvert` | Color inversion | (none) |
| `kCAFilterLuminanceToAlpha` | Map luminance to alpha | (none) |
| `kCAFilterBias` | Bias adjustment | `inputAmount` (Float) |
| `kCAFilterLanczosResize` | Lanczos resampling | `inputScale` (Float) |
| `kCAFilterDistanceField` | Distance field generation | (various) |

**Compositing/Blend Filters:**

| Constant | Purpose |
|----------|---------|
| `kCAFilterClear` | Clear blend |
| `kCAFilterCopy` | Copy blend |
| `kCAFilterSourceOver` | Source-over compositing |
| `kCAFilterSourceIn` | Source-in compositing |
| `kCAFilterSourceOut` | Source-out compositing |
| `kCAFilterSourceAtop` | Source-atop compositing |
| `kCAFilterDest` | Destination blend |
| `kCAFilterDestOver` | Destination-over compositing |
| `kCAFilterDestIn` | Destination-in compositing |
| `kCAFilterDestOut` | Destination-out compositing |
| `kCAFilterDestAtop` | Destination-atop compositing |
| `kCAFilterMultiplyBlendMode` | Multiply blend |
| `kCAFilterScreenBlendMode` | Screen blend |
| `kCAFilterOverlayBlendMode` | Overlay blend |
| `kCAFilterDarkenBlendMode` | Darken blend |
| `kCAFilterLightenBlendMode` | Lighten blend |
| `kCAFilterColorDodgeBlendMode` | Color dodge blend |
| `kCAFilterColorBurnBlendMode` | Color burn blend |
| `kCAFilterSoftLightBlendMode` | Soft light blend |
| `kCAFilterHardLightBlendMode` | Hard light blend |
| `kCAFilterDifferenceBlendMode` | Difference blend |
| `kCAFilterExclusionBlendMode` | Exclusion blend |

### 4.3 Applying Filters to Layers

```swift
// Apply filters to a regular CALayer
let layer = CALayer()
layer.filters = [blurFilter, saturateFilter]

// Animate filter values via keyPath
layer.setValue(20.0, forKeyPath: "filters.gaussianBlur.inputRadius")

// Apply as background filters (filter content behind the layer)
layer.backgroundFilters = [blurFilter]
```

### 4.4 Finding Filters in NSVisualEffectView

```swift
func inspectVisualEffectLayers(_ view: NSVisualEffectView) {
    guard let rootLayer = view.layer else { return }

    func printLayerTree(_ layer: CALayer, indent: Int = 0) {
        let prefix = String(repeating: "  ", count: indent)
        print("\(prefix)\(type(of: layer)) frame=\(layer.frame)")

        if let filters = layer.filters as? [NSObject] {
            for filter in filters {
                print("\(prefix)  filter: \(filter)")
            }
        }
        if let bgFilters = layer.backgroundFilters as? [NSObject] {
            for filter in bgFilters {
                print("\(prefix)  backgroundFilter: \(filter)")
            }
        }

        for sub in layer.sublayers ?? [] {
            printLayerTree(sub, indent: indent + 1)
        }
    }

    printLayerTree(rootLayer)
}
```

### 4.5 App Store Considerations

- CAFilter is **not** in public headers
- Using it risks App Store rejection
- Obfuscate class/method names if shipping to the store
- Consider alternatives: NSVisualEffectView (macOS) or UIVisualEffectView (iOS) for public API equivalents

---

## 5. CABackdropLayer

**Status:** Private class in QuartzCore
**Purpose:** The actual layer that performs backdrop sampling and filtering. The engine behind all system blur effects.

### 5.1 Class Interface (Private)

```objc
@interface CABackdropLayer : CALayer
@property BOOL windowServerAware;       // Must be YES for behind-window sampling
@property BOOL allowsInPlaceFiltering;  // YES = reuse buffer (can glitch), NO = separate buffer
@property BOOL allowsGroupBlending;     // Group with sibling backdrop layers
@property BOOL allowsGroupOpacity;      // Unified opacity for the group
@property BOOL disablesOccludedBackdropBlurs;  // Optimize by disabling hidden blurs
@property BOOL ignoresOffscreenGroups;
@property BOOL allowsHitTesting;
@property CGFloat scale;               // Sampling resolution (0.25 = quarter res)
@property CGFloat bleedAmount;         // Edge bleed for blur overflow
@property (copy) NSString *groupName;  // Group identifier for multi-backdrop coordination
@end
```

### 5.2 Creating a Custom Backdrop

```swift
// Step 1: Create the backdrop layer
let backdrop = NSClassFromString("CABackdropLayer")!.alloc() as! CALayer
backdrop.frame = view.bounds
backdrop.setValue(true, forKey: "windowServerAware")
backdrop.setValue(true, forKey: "allowsHitTesting")
backdrop.setValue(0.25, forKey: "scale")         // Quarter-res for performance
backdrop.setValue(0.2, forKey: "bleedAmount")     // Slight edge overflow

// Step 2: Create and apply filters
let blur = NSClassFromString("CAFilter")!
    .perform(NSSelectorFromString("filterWithType:"), with: "gaussianBlur")!
    .takeUnretainedValue() as! NSObject
blur.setValue(30.0, forKey: "inputRadius")
blur.setValue(true, forKey: "inputNormalizeEdges")

let saturate = NSClassFromString("CAFilter")!
    .perform(NSSelectorFromString("filterWithType:"), with: "colorSaturate")!
    .takeUnretainedValue() as! NSObject
saturate.setValue(1.8, forKey: "inputAmount")

backdrop.filters = [blur, saturate]

// Step 3: Add to layer hierarchy
view.layer?.addSublayer(backdrop)

// Step 4: Add tint overlay on top
let tint = CALayer()
tint.frame = view.bounds
tint.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
tint.compositingFilter = "softLightBlendMode"
view.layer?.addSublayer(tint)
```

### 5.3 Key Properties Explained

| Property | Default | Description |
|----------|---------|-------------|
| `scale` | 1.0 | Sampling resolution. 0.25 means sample at 1/4 resolution before filtering. Critical for performance. |
| `bleedAmount` | 0.0 | How far the blur extends beyond the layer's bounds. Prevents hard edges. |
| `windowServerAware` | false | Must be `true` for the layer to sample content behind the window via WindowServer. |
| `allowsInPlaceFiltering` | false | When `true`, reuses the buffer (faster but can show stale content / lag). |
| `groupName` | nil | Assign same string to multiple CABackdropLayers to composite as a single continuous surface. Without grouping, each backdrop samples independently, creating visible seams. |

### 5.4 WindowServer Behavior

- WindowServer automatically flattens the layer tree after ~1 second of inactivity for performance
- This composites the entire hierarchy into a single bitmap, eliminating the CABackdropLayer's ability to sample live content
- Any animation or property change "wakes up" the layer tree
- `allowsInPlaceFiltering = false` forces a separate buffer, preventing visual lag at the cost of memory

---

## 6. compositingFilter on CALayer

**Availability:** macOS only (NOT supported on iOS layers, despite the property existing)
**Purpose:** Defines how a layer composites with the content behind it using CIFilter blend modes.

### 6.1 API

```swift
// CALayer property (macOS only)
var compositingFilter: Any?  // CIFilter or String name
```

### 6.2 Setting Blend Modes

```swift
// By string name (most common)
layer.compositingFilter = "overlayBlendMode"
layer.compositingFilter = "multiplyBlendMode"
layer.compositingFilter = "softLightBlendMode"

// By CIFilter object
layer.compositingFilter = CIFilter(name: "CIOverlayBlendMode")
```

### 6.3 Complete List of Available Blend Mode Strings

These string names map to CIFilter compositing operations (CICategoryCompositeOperation):

**Darkening Modes:**
| String | Effect |
|--------|--------|
| `"multiplyBlendMode"` | Multiplies color values (always darkens) |
| `"colorBurnBlendMode"` | Darkens by increasing contrast |
| `"darkenBlendMode"` | Takes the darker of source and destination |
| `"linearBurnBlendMode"` | Darkens by decreasing brightness |

**Lightening Modes:**
| String | Effect |
|--------|--------|
| `"screenBlendMode"` | Inverse multiply (always lightens) |
| `"colorDodgeBlendMode"` | Lightens by decreasing contrast |
| `"lightenBlendMode"` | Takes the lighter of source and destination |
| `"linearDodgeBlendMode"` | Lightens by increasing brightness |

**Contrast Modes:**
| String | Effect |
|--------|--------|
| `"overlayBlendMode"` | Multiply if dark, screen if light |
| `"softLightBlendMode"` | Gentle version of overlay |
| `"hardLightBlendMode"` | Strong version of overlay |
| `"pinLightBlendMode"` | Replace if lighter/darker |

**Inversion Modes:**
| String | Effect |
|--------|--------|
| `"differenceBlendMode"` | Absolute difference of colors |
| `"exclusionBlendMode"` | Similar to difference, lower contrast |
| `"subtractBlendMode"` | Subtracts source from destination |
| `"divideBlendMode"` | Divides destination by source |

**Component Modes:**
| String | Effect |
|--------|--------|
| `"hueBlendMode"` | Hue from source, saturation+luminosity from dest |
| `"saturationBlendMode"` | Saturation from source |
| `"colorBlendMode"` | Hue+saturation from source, luminosity from dest |
| `"luminosityBlendMode"` | Luminosity from source |

**Compositing Modes:**
| String | CIFilter Name |
|--------|---------------|
| `"sourceAtopCompositing"` | `CISourceAtopCompositing` |
| `"sourceInCompositing"` | `CISourceInCompositing` |
| `"sourceOutCompositing"` | `CISourceOutCompositing` |
| `"additionCompositing"` | `CIAdditionCompositing` |

### 6.4 Practical Example: Tint Overlay with Blend

```swift
// Create a tint overlay that blends with content using soft light
let tintLayer = CALayer()
tintLayer.frame = parentLayer.bounds
tintLayer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
tintLayer.compositingFilter = "softLightBlendMode"
parentLayer.addSublayer(tintLayer)

// This creates a subtle blue tint that interacts with the underlying
// content rather than simply covering it
```

### 6.5 backgroundFilters (macOS)

```swift
// Apply filters to content BEHIND the layer (not the layer itself)
layer.backgroundFilters = [
    CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 20])!
]

// Note: backgroundFilters is also macOS-only
```

---

## 7. SwiftUI Background Modifiers

### 7.1 .background with Materials

```swift
// Basic material background
Text("Content")
    .background(.ultraThinMaterial)

// Material with shape
Text("Rounded")
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

// Material with safe area behavior
List { ... }
    .background(.thinMaterial, ignoresSafeAreaEdges: .all)
```

### 7.2 presentationBackground (iOS 16.4+ / macOS 13.3+)

Customizes the background of modal presentations (sheets, popovers).

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationBackground(.ultraThinMaterial)  // Frosted glass sheet
}

// With a color
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationBackground(.blue.opacity(0.3))
}

// With a custom view
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationBackground {
            LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                .opacity(0.5)
        }
}
```

The presentation background automatically fills the entire presentation area and allows views behind to show through translucent styles.

### 7.3 presentationBackgroundInteraction (iOS 16.4+)

Controls whether users can interact with content behind a presented sheet.

```swift
.sheet(isPresented: $showSheet) {
    SheetContent()
        .presentationBackground(.thinMaterial)
        .presentationBackgroundInteraction(.enabled)  // Allow taps behind sheet
}
```

### 7.4 containerBackground (iOS 17+ / macOS 14+)

Customizes backgrounds for specific container contexts.

```swift
// Window background (macOS 15+)
WindowGroup {
    ContentView()
        .containerBackground(.ultraThinMaterial, for: .window)
}

// Navigation bar background
NavigationStack {
    List { ... }
        .containerBackground(.thickMaterial, for: .navigation)  // iOS 18+
}

// TabView background
TabView {
    ContentView()
        .containerBackground(.thinMaterial, for: .tabView)
}
```

### 7.5 toolbarBackground

```swift
NavigationStack {
    ContentView()
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
}

// Hide toolbar background entirely
ContentView()
    .toolbarBackground(.hidden, for: .windowToolbar)  // macOS
```

---

## 8. MenuBarExtra Styling

**Availability:** macOS 13+

### 8.1 Styles

```swift
// Menu style (default) - renders as standard NSMenu
MenuBarExtra("App", systemImage: "star") {
    Button("Quit") { NSApp.terminate(nil) }
}
.menuBarExtraStyle(.menu)

// Window style - renders as a detached panel with custom SwiftUI content
MenuBarExtra("App", systemImage: "star") {
    CustomPanelView()
        .frame(width: 300, height: 400)
}
.menuBarExtraStyle(.window)
```

### 8.2 Window Style: Transparent/Glass Panels

The `.window` style creates an NSPanel under the hood. To customize it:

```swift
// Using MenuBarExtraAccess library (orchetect/MenuBarExtraAccess)
MenuBarExtra("App", systemImage: "star") {
    CustomView()
        .introspectMenuBarExtraWindow { window in
            // Access the underlying NSWindow/NSPanel
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false

            // Add visual effect
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .hudWindow
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            window.contentView = visualEffect
            // Add your SwiftUI hosting view as subview of visualEffect
        }
}
.menuBarExtraStyle(.window)
```

### 8.3 Chrome Stripping Techniques

To remove the default window chrome from a MenuBarExtra panel:

1. Access the underlying NSPanel via introspection
2. Set `styleMask` to `[.borderless, .nonactivatingPanel]`
3. Set `isOpaque = false` and `backgroundColor = .clear`
4. Add NSVisualEffectView as the content view
5. Add your SwiftUI content via NSHostingView as a subview

### 8.4 Limitations

- `.menu` style ignores custom button styles and images
- `.window` style cannot be programmatically shown/hidden without the MenuBarExtraAccess library
- SwiftUI does not natively expose the underlying NSWindow for `.window` style

---

## 9. NSPanel and Transparent Windows

**Class:** `NSPanel` (subclass of `NSWindow`)
**Purpose:** Auxiliary windows for floating panels, inspectors, HUDs.

### 9.1 Creating a Floating Transparent Panel

```swift
class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Transparency
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Floating behavior
        level = .floating                    // Above normal windows
        isMovableByWindowBackground = true   // Drag from anywhere
        hidesOnDeactivate = false            // Stay visible when app loses focus

        // Glass background
        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        contentView = visualEffect
    }
}
```

### 9.2 Key NSPanel Properties

```swift
// Style mask options specific to NSPanel
struct StyleMask {
    static let nonactivatingPanel  // Does not activate the owning app
    // Combine with standard NSWindow masks:
    // .borderless, .titled, .closable, .resizable, .fullSizeContentView
}

// Behavior
panel.becomesKeyOnlyIfNeeded = true  // Only become key when a text field is clicked
panel.worksWhenModal = true          // Respond to events during modal sessions
panel.isFloatingPanel = true         // Float above standard windows
```

### 9.3 Nonactivating Behavior Caveat

There is a known AppKit issue: changing the `.nonactivatingPanel` flag after initialization does not fully update the window's activation behavior. The workaround is to set the flag at initialization time in the `styleMask` parameter of `init()`.

### 9.4 Spotlight/Alfred-Style Window

```swift
class SpotlightPanel: NSPanel {
    init() {
        let rect = NSRect(x: 0, y: 0, width: 600, height: 44)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        center()

        let blur = NSVisualEffectView(frame: rect)
        blur.material = .popover
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 22
        blur.layer?.masksToBounds = true
        contentView = blur
    }
}
```

---

## 10. NSWindow Style Masks and Titlebar

### 10.1 Complete StyleMask Values

```swift
struct NSWindow.StyleMask: OptionSet {
    static let borderless           = StyleMask(rawValue: 0)       // No chrome at all
    static let titled               = StyleMask(rawValue: 1 << 0)  // Title bar
    static let closable             = StyleMask(rawValue: 1 << 1)  // Close button
    static let miniaturizable       = StyleMask(rawValue: 1 << 2)  // Minimize button
    static let resizable            = StyleMask(rawValue: 1 << 3)  // Resize controls
    static let utilityWindow        = StyleMask(rawValue: 1 << 4)  // Utility panel style
    static let docModalWindow       = StyleMask(rawValue: 1 << 6)  // Document modal
    static let nonactivatingPanel   = StyleMask(rawValue: 1 << 7)  // NSPanel only
    static let texturedBackground   = StyleMask(rawValue: 1 << 8)  // Deprecated
    static let unifiedTitleAndToolbar = StyleMask(rawValue: 1 << 12)
    static let hudWindow            = StyleMask(rawValue: 1 << 13) // HUD style
    static let fullScreen           = StyleMask(rawValue: 1 << 14) // Full screen capable
    static let fullSizeContentView  = StyleMask(rawValue: 1 << 15) // Content extends under titlebar
}
```

### 10.2 Transparent Titlebar Patterns

```swift
// Pattern 1: Transparent titlebar with visible traffic lights
window.titlebarAppearsTransparent = true
window.titleVisibility = .hidden
window.styleMask.insert(.fullSizeContentView)

// Pattern 2: Full bleed content (content goes under titlebar)
window.titlebarAppearsTransparent = true
window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
// Add NSVisualEffectView as contentView for glass effect

// Pattern 3: Completely chromeless
window.styleMask = [.borderless, .fullSizeContentView]
window.isOpaque = false
window.backgroundColor = .clear
window.isMovableByWindowBackground = true

// Pattern 4: Sidebar-style with visual effect
window.titlebarAppearsTransparent = true
window.styleMask.insert(.fullSizeContentView)
let sidebar = NSVisualEffectView()
sidebar.material = .sidebar
sidebar.blendingMode = .behindWindow
// Position as split view source list
```

### 10.3 SwiftUI Window Styles

```swift
// Hidden title bar
WindowGroup {
    ContentView()
}
.windowStyle(.hiddenTitleBar)

// Plain window (macOS 15+)
WindowGroup {
    ContentView()
}
.windowStyle(.plain)

// Toolbar style
WindowGroup {
    ContentView()
}
.windowToolbarStyle(.unified)           // Standard unified
.windowToolbarStyle(.unifiedCompact)    // Compact unified
.windowToolbarStyle(.expanded)          // Expanded toolbar

// Enable background dragging
WindowGroup {
    ContentView()
}
.windowStyle(.hiddenTitleBar)
.windowBackgroundDragBehavior(.enabled)

// Translucent window background
WindowGroup {
    ContentView()
        .containerBackground(.ultraThinMaterial, for: .window)
}
```

---

## 11. Dark Mode / Light Mode and Vibrancy

### 11.1 NSAppearance

```swift
// System appearances
NSAppearance(named: .aqua)              // Standard light
NSAppearance(named: .darkAqua)          // Standard dark
NSAppearance(named: .vibrantLight)      // Vibrancy-optimized light
NSAppearance(named: .vibrantDark)       // Vibrancy-optimized dark
NSAppearance(named: .accessibilityHighContrastAqua)
NSAppearance(named: .accessibilityHighContrastDarkAqua)
NSAppearance(named: .accessibilityHighContrastVibrantLight)
NSAppearance(named: .accessibilityHighContrastVibrantDark)
```

### 11.2 How Vibrancy Works

Vibrancy is a rendering mode where content on top of an NSVisualEffectView is drawn with special blend modes that allow it to interact with the blurred background. This makes text, icons, and controls appear to be "part of" the translucent surface rather than floating above it.

**Mechanism:**
1. NSVisualEffectView sets the `interiorBackgroundStyle` to `.light` or `.dark`
2. Child views that respect vibrancy (NSTextField, NSImageView, etc.) draw using special compositing
3. The vibrant appearance names (`.vibrantLight`, `.vibrantDark`) tell controls to render with appropriate blend modes
4. System colors like `NSColor.labelColor` automatically adapt for vibrancy

### 11.3 How Materials Adapt

Each material has two internal recipes:
- **Active appearance** (window is key): More saturated, vibrant
- **Inactive appearance** (window in background): Desaturated, muted

And two color schemes:
- **Light mode**: Light tint overlay, typically white-ish
- **Dark mode**: Dark tint overlay, typically dark gray/black-ish

Materials automatically select the correct recipe based on:
- The window's `effectiveAppearance`
- Whether the window is key/main
- System accessibility settings

### 11.4 Observing Appearance Changes

```swift
// In NSView subclass
override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateCustomColors()
}

// Check current mode
func isDarkMode() -> Bool {
    let appearance = effectiveAppearance
    let match = appearance.bestMatch(from: [.aqua, .darkAqua])
    return match == .darkAqua
}

// In NSViewController / NSWindowController
override func viewDidLoad() {
    super.viewDidLoad()
    // Observe at app level
    observation = NSApp.observe(\.effectiveAppearance) { app, _ in
        print("System appearance changed to: \(app.effectiveAppearance.name)")
    }
}

// SwiftUI
@Environment(\.colorScheme) var colorScheme
// colorScheme == .dark or .light
```

### 11.5 Force Specific Appearance

```swift
// Force dark on a view hierarchy
view.appearance = NSAppearance(named: .darkAqua)

// Force dark on entire window
window.appearance = NSAppearance(named: .darkAqua)

// Force dark on entire app
NSApp.appearance = NSAppearance(named: .darkAqua)

// SwiftUI
ContentView()
    .preferredColorScheme(.dark)
```

### 11.6 Reduced Transparency

When the user enables "Reduce Transparency" in accessibility settings, all materials degrade to solid opaque backgrounds. Always test your glass UI with this setting.

```swift
// Check programmatically
let isReduced = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

// Observe changes
NotificationCenter.default.addObserver(
    forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
    object: nil, queue: .main
) { _ in
    // Update UI
}

// SwiftUI
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
```

---

## 12. Performance Considerations

### 12.1 GPU Cost Hierarchy (cheapest to most expensive)

1. **Solid color background** -- negligible
2. **SwiftUI `.ultraThickMaterial`** -- minimal blur, mostly opaque
3. **`.withinWindow` blending** -- composites only within window layer tree
4. **SwiftUI `.ultraThinMaterial`** -- larger blur kernel
5. **`.behindWindow` blending** -- requires WindowServer involvement
6. **Multiple overlapping NSVisualEffectViews** -- each adds a compositing pass
7. **Custom CABackdropLayer with high inputRadius** -- expensive blur kernel
8. **Liquid Glass with interactive behaviors** -- lensing + specular + motion tracking

### 12.2 Optimization Techniques

**Scale property on CABackdropLayer:**
```swift
// Sample at quarter resolution (4x fewer pixels to blur)
backdrop.setValue(0.25, forKey: "scale")  // 0.25 is the sweet spot
```

**Minimize blur radius:**
```swift
// inputRadius of 15-30 is typical; >50 is rarely needed and expensive
blur.setValue(20.0, forKey: "inputRadius")
```

**WindowServer flattening:**
- WindowServer automatically flattens inactive layer trees after ~1 second
- This eliminates live sampling overhead for static content
- Any property animation "wakes up" the tree

**Reduce number of visual effect views:**
- Each behindWindow view requires a separate WindowServer compositing pass
- Combine adjacent regions into a single NSVisualEffectView when possible
- Use `.withinWindow` instead of `.behindWindow` when the blur only needs to cover sibling content

**Disable when not visible:**
```swift
// Set state to inactive when the panel is hidden
visualEffectView.state = .inactive  // Stops all compositing
```

### 12.3 Liquid Glass Performance

- Liquid Glass uses Metal shaders for real-time lensing and specular effects
- Interactive behaviors (shimmer, bounce) add per-frame GPU work
- GlassEffectContainer optimizes rendering by sharing the sampling region
- Keep glass elements to the navigation layer; do not cover large content areas

### 12.4 Memory Considerations

- `allowsInPlaceFiltering = true` saves memory by reusing buffers (but can show stale content)
- `allowsInPlaceFiltering = false` allocates separate buffers (correct but more memory)
- Lower `scale` values (e.g., 0.25) reduce memory for the downsampled texture

---

## 13. Apple HIG Best Practices

### 13.1 When to Use Glass / Materials

**DO use glass for:**
- Navigation bars and toolbars
- Tab bars
- Sidebars and source lists
- Popovers and floating panels
- HUD overlays
- Menu backgrounds
- Sheet backgrounds
- Status bars

**DO NOT use glass for:**
- Primary content areas (lists, tables, grids)
- Text bodies or article content
- Media playback surfaces
- Form inputs and data entry areas
- Full-screen backgrounds (use solid colors)

### 13.2 Depth Hierarchy

Apple's material system establishes three depth layers:

1. **Base layer** -- Solid content (images, text, data)
2. **Material layer** -- Translucent surfaces (sidebars, sheets) using materials
3. **Navigation layer** -- Glass controls floating above content (Liquid Glass in iOS 26+)

Rules:
- Content always at the bottom
- Materials provide intermediate depth
- Glass floats on top for controls and navigation
- Never stack multiple glass layers directly on each other
- Glass cannot sample other glass (use GlassEffectContainer)

### 13.3 Accessibility

- Always test with "Reduce Transparency" enabled
- Ensure text contrast meets WCAG guidelines even on translucent surfaces
- Materials automatically handle high contrast mode
- Liquid Glass depth should be <= 20 for UI controls
- Frost values of 10--25 are recommended for accessible translucency
- Use `.thickMaterial` or `.ultraThickMaterial` when readability is paramount

### 13.4 Platform Adaptation

- Materials render differently per platform (macOS is lighter/more translucent than iOS)
- Dark mode materials are typically less translucent than light mode
- visionOS materials interact with the real-world environment
- Always use semantic materials (`.sidebar`, `.popover`) over explicit ones (`.dark`, `.light`)

---

## Quick Reference: Choosing the Right API

| Goal | API | Platform |
|------|-----|----------|
| Sidebar blur | `NSVisualEffectView(.sidebar, .behindWindow)` | macOS |
| SwiftUI frosted card | `.background(.thinMaterial)` | Cross-platform |
| Glass navigation button | `.glassEffect()` | iOS 26+ / macOS 26+ |
| Custom blur radius | `CABackdropLayer` + `CAFilter` (private) | macOS |
| Layer blend mode | `layer.compositingFilter = "overlayBlendMode"` | macOS |
| Floating HUD panel | `NSPanel` + `NSVisualEffectView(.hudWindow)` | macOS |
| Translucent sheet | `.presentationBackground(.thinMaterial)` | iOS 16.4+ |
| Menu bar glass panel | `MenuBarExtra` + `.window` style | macOS 13+ |
| Full-window material | `.containerBackground(.material, for: .window)` | macOS 14+ |
| UIKit glass button | `UIGlassEffect` + `UIVisualEffectView` | iOS 26+ |
| AppKit glass element | `NSGlassEffectView` | macOS 26+ |

---

## Key Resources and References

### Apple Official Documentation
- [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview)
- [NSVisualEffectView.Material](https://developer.apple.com/documentation/appkit/nsvisualeffectview/material)
- [NSVisualEffectView.BlendingMode](https://developer.apple.com/documentation/appkit/nsvisualeffectview/blendingmode-swift.enum)
- [SwiftUI Material](https://developer.apple.com/documentation/swiftui/material/)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [compositingFilter](https://developer.apple.com/documentation/quartzcore/calayer/1410748-compositingfilter)
- [HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [NSWindow.StyleMask](https://developer.apple.com/documentation/appkit/nswindow/stylemask)
- [NSPanel](https://developer.apple.com/documentation/appkit/nspanel)
- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)

### WWDC Sessions
- [Build a SwiftUI app with the new design (WWDC25-323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Build a UIKit app with the new design (WWDC25-284)](https://developer.apple.com/videos/play/wwdc2025/284/)
- [Build an AppKit app with the new design (WWDC25-310)](https://developer.apple.com/videos/play/wwdc2025/310/)
- [Advanced Dark Mode (WWDC18-218)](https://developer.apple.com/videos/play/wwdc2018/218)
- [Tailor macOS windows with SwiftUI (WWDC24-10148)](https://developer.apple.com/videos/play/wwdc2024/10148/)

### Community Resources
- [Reverse Engineering NSVisualEffectView -- Oskar Groth](https://oskargroth.com/blog/reverse-engineering-nsvisualeffectview)
- [DIY NSVisualEffectView using Private API (Gist)](https://gist.github.com/avaidyam/d3c76df710651edbf4da56bad3fea9d2)
- [CABackdropLayer & CAPluginLayer -- Aditya Vaidyam](https://medium.com/@avaidyam/capluginlayer-cabackdroplayer-f56e85d9dc2c)
- [CAFilter Private Header (QuartzInternal)](https://github.com/avaidyam/QuartzInternal/blob/master/CoreAnimationPrivate/CAFilter.h)
- [NSVisualEffectView Undocumentation -- Sindre Sorhus](https://gist.github.com/sindresorhus/23c3e88c7685d77b95a8c380d08cbd45)
- [NSWindowStyles Showcase -- Luka Kerr](https://github.com/lukakerr/NSWindowStyles)
- [Liquid Glass Reference -- Conor Luddy](https://github.com/conorluddy/LiquidGlassReference)
- [ShatteredGlass Deconstruction -- AlexStrNik](https://github.com/AlexStrNik/ShatteredGlass)
- [Xcode 26 System Prompts: AppKit Liquid Glass](https://github.com/artemnovichkov/xcode-26-system-prompts/blob/main/AdditionalDocumentation/AppKit-Implementing-Liquid-Glass-Design.md)
- [Xcode 26 System Prompts: UIKit Liquid Glass](https://github.com/artemnovichkov/xcode-26-system-prompts/blob/main/AdditionalDocumentation/UIKit-Implementing-Liquid-Glass-Design.md)
- [Dark Side of the Mac: Appearance & Materials](https://mackuba.eu/2018/07/04/dark-side-mac-1/)
- [MenuBarExtraAccess Library](https://github.com/orchetect/MenuBarExtraAccess)
- [CompositingFilters Experiment](https://github.com/arthurschiller/CompositingFilters)
- [Vibrancy, NSAppearance, and Visual Effects](https://philz.blog/vibrancy-nsappearance-and-visual-effects-in-modern-appkit-apps/)
