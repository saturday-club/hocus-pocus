# Liquid Glass Reference (macOS 26 Tahoe)

## API

```swift
// Basic usage
.glassEffect(.regular, in: .rect(cornerRadius: 16))
.glassEffect(.clear, in: .capsule)
.glassEffect(.regular.interactive())        // hover/press animations
.glassEffect(.regular.tint(.blue))          // semantic color tint

// Prevent glass shapes from merging
GlassEffectContainer(spacing: 0) { ... }

// Morph transitions
.glassEffectID("id", in: namespace)
.glassEffectUnion(id: "group", namespace: namespace)
```

## Glass Variants

| Variant    | Transparency | Adapts to background | Use case                    |
|------------|-------------|---------------------|-----------------------------|
| `.regular` | Medium      | YES (flips light/dark) | Navigation, controls, tiles |
| `.clear`   | High        | NO (shows through)     | Over photos/video/media     |
| `.identity`| None        | N/A                    | Conditional disable         |

## Key Behavior: Glass Samples What's Behind It

Glass bends/concentrates light from content underneath. On transparent windows
(`backgroundColor = .clear`), it samples the DESKTOP -- if dark, glass renders dark.

### Solutions for Consistent Appearance

1. **Subtle backing layer** -- give glass something light to sample:
   ```swift
   content
       .background(Color.white.opacity(0.15))
       .glassEffect(.regular, in: .rect(cornerRadius: 20))
   ```

2. **Force appearance** (nuclear option -- makes everything light/dark):
   ```swift
   panel.appearance = NSAppearance(named: .aqua)  // force light
   ```

3. **Tint toward light**:
   ```swift
   .glassEffect(.regular.tint(.white), in: .rect(cornerRadius: 20))
   ```

## How Apple's Control Center Works

- Uses `.regular` glass on tiles
- Tiles are inside a window with its OWN content (not transparent window)
- Glass samples the CC's own background, not the desktop
- Small elements flip light/dark adaptively
- Large elements (sidebars) stay consistent

## NSPanel Setup for Glass

```swift
let panel = NSPanel(...)
panel.isOpaque = false
panel.backgroundColor = .clear
panel.level = .floating
// panel.appearance = NSAppearance(named: .aqua)  // ONLY if you want forced light
```

## Rules

- Apply glass to navigation/controls only, never scrollable content
- Never stack glass on glass -- use GlassEffectContainer
- Apply .glassEffect() AFTER padding, font, foregroundStyle
- Use tint only for semantic meaning

## Sources

- WWDC25 Session 219: "Meet Liquid Glass"
- WWDC25 Session 310: "Build an AppKit app with the new design"
- developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- developer.apple.com/documentation/SwiftUI/View/glassEffect(_:in:)
