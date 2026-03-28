# hocus-pocus

A native macOS focus overlay. Dims, blurs, and textures everything except your active window so you can concentrate.

Built from scratch with Swift + AppKit + Metal. Inspired by [Monocle](https://heyimo.com/monocle) -- reverse-engineered from behavioral observation, not source code.

## Install

```bash
git clone https://github.com/saturday-club/hocus-pocus.git
cd hocus-pocus
./scripts/bundle.sh
open build/AutoFocus.app
```

Grant **Accessibility** permission when prompted (System Settings > Privacy & Security > Accessibility). This is needed once and persists across rebuilds thanks to ad-hoc codesigning.

## Features

| Feature | Status |
|---------|--------|
| Deep focus mode (full overlay behind active window) | Done |
| Ambient mode (gradient falloff) | Done |
| Gaussian blur with adjustable radius | Done |
| Organic frosted-glass grain shader | Done |
| Color tint with 7 presets | Done |
| Grayscale / mono mode | Done |
| Shake to toggle | Done |
| Shift+Shake to peek | Done |
| Global hotkeys (Cmd+Shift+F/M/E) | Done |
| URL scheme automation | Done |
| Excluded apps | Done |
| Multi-display support | Done |
| Fullscreen app detection | Done |
| Fade in/out transitions | Done |
| Glass-style menu bar panel (MenuBarExtra .window) | Done |

## Controls

| Action | Method |
|--------|--------|
| Toggle overlay | Cmd+Shift+F, menu bar icon, or shake mouse |
| Cycle mode (deep/ambient) | Cmd+Shift+M |
| Exclude current app | Cmd+Shift+E |
| Peek (temporary disable) | Hold Shift + shake mouse |
| Settings | Menu bar > More, or Cmd+, |

**URL scheme:**
```
autofocus://toggle | on | off
autofocus://mode/toggle | ambient | deep
autofocus://ignore | unignore
```

## Architecture

### Window Ordering (not masking)

The critical architectural insight, discovered by reverse-engineering Monocle's live window state:

**Monocle does not use a mask cutout.** Its overlay window sits at `NSWindow.level = .normal` (layer 0) and uses `order(.below, relativeTo: focusedWindowID)` to position itself just behind the active window. The focused window naturally occludes the overlay.

We replicate this exactly. Benefits over the mask approach:
- Zero coordinate alignment issues (no gap around the window)
- The window's own visual bounds (shadow, rounded corners, toolbar) define the "cutout"
- No CAShapeLayer mask rebuild on every frame
- Works with any window shape or decoration

### CAFilter Blur Injection

Stock `NSVisualEffectView` materials cap blur radius at modest values. Monocle bypasses this by injecting custom `inputRadius` values into the private `CAFilter` on the backdrop layer.

We do the same: `BlurView` subclasses `NSVisualEffectView`, walks the layer tree to find `CAFilter` instances, and sets `inputRadius` to a custom value (0-40pt, mapped from the blur slider). KVO on `sublayers` re-applies the filter when the system resets it (appearance changes, etc.).

### Organic Grain Shader

Monocle's `grainShader` Metal function takes only `position` and `intensity` (no time uniform) and uses `framebuffer_fetch_enable` to modify the blur in-place.

Our grain shader uses multi-octave interpolated value noise:
- Two octaves (coarse 0.6 + fine 0.4) for natural texture
- Slow drift (changes every ~3 seconds) instead of per-frame flickering
- Very low alpha (0.08 * intensity) for subtle frosted-glass appearance
- Half resolution with bilinear filtering
- Only re-renders every 2 seconds (near-zero GPU cost)

### Event-Driven Window Tracking

Instead of polling `CGWindowListCopyWindowInfo` at 30Hz:
- `NSWorkspace.didActivateApplicationNotification` for app switches
- `AXObserver` per frontmost app for focus/move/resize events
- Global mouse click monitor for immediate re-poll on click
- 10Hz fallback poll with skip-if-unchanged logic
- 2-second safety net for edge cases

Result: 0.1% CPU vs 5-7% with pure polling.

### Fullscreen Handling

When the focused app enters native macOS fullscreen:
- Overlay hides (the fullscreen app fills the Space, no dimming needed)
- `activeSpaceDidChangeNotification` triggers re-evaluation on Space switch
- Overlay reappears when switching back to a normal Space
- `.fullScreenAuxiliary` collection behavior allows coexistence

## Repository Layout

```
Package.swift                           # SPM manifest
Sources/AutoFocus/
  App/
    AutoFocusApp.swift                  # @main, MenuBarExtra (.window style)
    AppDelegate.swift                   # Lifecycle, wiring, URL scheme
    AppState.swift                      # @Observable central state
  Window/
    WindowPoller.swift                  # Event-driven + fallback polling
    WindowSnapshot.swift                # CG window info value type
    AccessibilityBridge.swift           # AXUIElement wrapper
  Overlay/
    OverlayManager.swift                # Per-display overlay lifecycle
    OverlayWindow.swift                 # NSWindow at level 0, fade animations
    OverlayContentView.swift            # Blur + tint + grain layer stack
  Effects/
    BlurView.swift                      # NSVisualEffectView + CAFilter injection
    MaskBuilder.swift                   # CAShapeLayer mask (ambient mode only)
    TintLayer.swift                     # Color overlay with opacity
    GrainRenderer.swift                 # Metal compute pipeline
    GrayscaleFilter.swift               # CIColorControls desaturation
  Settings/
    MenuBarPanel.swift                  # Glass-style menu bar dropdown
    SettingsView.swift                  # Full settings window (tabs)
    ExcludedAppsView.swift              # Excluded apps management
  Automation/
    HotkeyManager.swift                 # Carbon RegisterEventHotKey
    URLSchemeHandler.swift              # autofocus:// routes
    ShakeDetector.swift                 # Mouse shake gesture detection
  Persistence/
    Defaults.swift                      # UserDefaults keys, FocusMode, TintPresets
    ExcludedAppsStore.swift             # Persisted excluded app set
  Resources/
    GrainShader.metal                   # Multi-octave value noise kernel
scripts/
  bundle.sh                             # Build + create .app bundle + codesign
  collect_monocle_artifacts.sh          # Monocle inspection script
docs/
  monocle_notes.md                      # Behavioral findings from Monocle
  reverse_engineering_plan.md           # Structured RE plan
```

## Reverse Engineering Findings

Key discoveries from inspecting Monocle 3.0.3 (build 15) at runtime:

| Finding | Technique | Impact |
|---------|-----------|--------|
| Overlay at layer 0, ordered behind focused window | `CGWindowListCopyWindowInfo` comparison | Eliminated mask cutout entirely |
| `CAFilter` gaussianBlur with custom `inputRadius` | `otool -ov` class dump + `strings` | Unlocked adjustable blur radius |
| Grain shader is static (no time uniform) | `strings` on `default.metallib` | Switched to near-static grain (2s refresh) |
| `framebuffer_fetch_enable` in grain shader | Metal shader string analysis | Confirmed in-place blur modification |
| `observedBackdrop` + `observedRootLayer` KVO | `otool -ov` ivar dump | Re-apply filters on system resets |
| `customWindowsToEnterFullScreenForWindow:` | `strings` delegate method scan | Informed fullscreen Space handling |
| Tint opacity 0.225, preset "Blue" | `defaults read dk.heyiam.monocle` | Calibrated default tint values |

## Performance

| Metric | Value |
|--------|-------|
| CPU (idle, overlay active) | 0.1% |
| Grain renders per second | 0.5 |
| Memory | ~80 MB |
| Window polling | Event-driven (10Hz fallback) |
| Mask rebuilds (deep mode) | 0 |

## Build

Requires:
- macOS 14.6+
- Xcode 26+ / Swift 6.2+
- Metal-capable GPU

```bash
# Debug
swift build && swift run

# Release .app bundle
./scripts/bundle.sh
open build/AutoFocus.app
```

## Building This With an AI Agent: A Detailed Guide

This project was built entirely in a single Claude Code session. If you want to reproduce this with your own agent (Claude, GPT, Copilot, etc.), here is exactly how to approach it, step by step.

### Phase 1: Research Before Code

**Do not write any code yet.** Start by understanding the target app.

1. **Collect artifacts from the installed app** (if available):
   ```bash
   # Extract class names, method signatures, ivars
   otool -ov /Applications/TargetApp.app/Contents/MacOS/TargetApp > objc-metadata.txt
   strings -a /Applications/TargetApp.app/Contents/MacOS/TargetApp > strings.txt
   plutil -p /Applications/TargetApp.app/Contents/Info.plist > info.txt
   codesign -d --entitlements :- /Applications/TargetApp.app > entitlements.txt
   ```

2. **Inspect live window state** while the app is running:
   ```python
   import Quartz
   windows = Quartz.CGWindowListCopyWindowInfo(Quartz.kCGWindowListOptionAll, Quartz.kCGNullWindowID)
   for w in windows:
       if 'TargetApp' in str(w.get('kCGWindowOwnerName', '')):
           print(w)  # Layer, bounds, alpha, memory, onscreen status
   ```

3. **Read user preferences** to understand default values:
   ```bash
   defaults read com.target.bundleid
   ```

4. **Feed all findings to the agent** as context before asking it to write code. The agent needs to know:
   - What window level the target uses (layer 0 vs elevated)
   - What rendering technique (CAFilter, CIFilter, Metal shader)
   - What KVO paths it observes
   - What delegate methods it implements

### Phase 2: Architecture Decision

The single most important architectural decision for a focus overlay app is **mask-based vs ordering-based window isolation**.

**Mask approach** (what most people try first):
- Overlay at elevated window level (.statusBar, layer 25)
- CAShapeLayer mask with a cutout for the focused window
- Problem: coordinate alignment between CG/AX frames and the visual window edge causes visible gaps
- Problem: rebuilding the mask every frame is expensive

**Ordering approach** (what Monocle does, and what works):
- Overlay at normal window level (layer 0)
- `NSWindow.order(.below, relativeTo: focusedWindowNumber)` to position behind the active window
- The focused window naturally occludes the overlay
- Zero alignment issues because the window's own visual bounds define the edge

Tell your agent explicitly: "Use window ordering, not mask cutouts. Set the overlay at `.normal` level and order it below the focused window."

### Phase 3: Blur Quality

Stock `NSVisualEffectView` materials cap blur radius at modest values. To get a deeper, richer blur:

1. Subclass `NSVisualEffectView`
2. After the view moves to a window, walk `layer.sublayers` recursively
3. Find any `CAFilter` instances (private class, but accessible via string type checking)
4. Set `inputRadius` to your desired value (20-40pt for deep blur)
5. KVO-observe `sublayers` on the root layer to re-apply when macOS resets filters (appearance changes, space transitions)

```swift
private func applyBlurToLayerTree(_ layer: CALayer) {
    if let filters = layer.filters as? [NSObject] {
        for filter in filters {
            let typeName = String(describing: type(of: filter))
            if typeName.contains("CAFilter") {
                filter.setValue(customBlurRadius, forKey: "inputRadius")
            }
        }
    }
    // Also check backgroundFilters, then recurse into sublayers
}
```

Tell your agent: "Subclass NSVisualEffectView and inject custom inputRadius values into CAFilter instances found in the layer tree. Re-apply on viewDidChangeEffectiveAppearance and via KVO on sublayers."

### Phase 4: Grain Shader

The grain texture that makes blur overlays look like frosted glass instead of a flat color wash:

1. **Use multi-octave value noise**, not hash noise. Hash noise produces TV static. Value noise with smooth interpolation (hermite `f*f*(3-2*f)`) produces organic texture.
2. **Two octaves**: coarse (weight 0.6) + fine (weight 0.4). More octaves add computational cost without visible improvement at low alpha.
3. **Near-static**: Monocle's grain has no time uniform. Ours drifts very slowly (every ~3 seconds) for subtle life without flicker.
4. **Very low alpha**: 0.08 * intensity. The grain should be barely perceptible, not noisy.
5. **Render infrequently**: Since it's near-static, render every 2 seconds, not every frame. This drops GPU cost to near zero.

Tell your agent: "Write a Metal compute kernel using interpolated value noise (not hash noise) with 2 octaves. Output at very low alpha (0.08 * intensity). Render to a CAMetalLayer at half resolution with bilinear filtering, updating every 2 seconds."

### Phase 5: Window Detection

Do not poll `CGWindowListCopyWindowInfo` at 30Hz. Instead:

1. **NSWorkspace.didActivateApplicationNotification** for app switches (free, instant)
2. **AXObserver per frontmost app** for focus/move/resize events within the app:
   ```swift
   AXObserverCreate(pid, callback, &observer)
   AXObserverAddNotification(observer, appElement, kAXFocusedWindowChangedNotification, ...)
   AXObserverAddNotification(observer, appElement, kAXWindowMovedNotification, ...)
   CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
   ```
3. **Global mouse click monitor** for immediate re-poll:
   ```swift
   NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { _ in
       needsUpdate = true
   }
   ```
4. **10Hz fallback timer** with skip-if-unchanged logic as a safety net

Tell your agent: "Use AXObserver for event-driven window tracking. Set up observers for kAXFocusedWindowChangedNotification, kAXWindowMovedNotification, kAXWindowResizedNotification on the frontmost app. Rebuild the observer when the frontmost app changes. Use a 10Hz fallback poll that skips work when needsUpdate is false."

### Phase 6: Shake Detection

The shake-to-toggle gesture requires a **sustained shake**, not a simple direction-change count. Without the sustain requirement, normal mouse movement triggers false positives.

Algorithm:
1. Track mouse X positions with timestamps in a sliding window (0.3-0.8s depending on sensitivity)
2. Count direction reversals where each segment exceeds a minimum pixel distance
3. When reversals reach threshold, start a sustain timer (300ms)
4. Only fire if shaking continues through the sustain period
5. If no reversal detected for 200ms during sustain, reset

Sensitivity adjusts three parameters simultaneously:
- Time window (shorter = need faster shaking)
- Minimum move distance per reversal (smaller = less arm effort)
- Required reversals before sustain starts (fewer = triggers sooner)

Tell your agent: "Implement shake detection with a two-phase approach: phase 1 accumulates direction reversals, phase 2 requires sustained shaking for 300ms after the threshold. Add a sensitivity parameter (0.1-1.0) that adjusts window duration, move distance, and reversal count together."

### Phase 7: Fullscreen Handling

macOS fullscreen apps get their own Space. Your overlay needs to:

1. Detect fullscreen by checking if the frontmost app has a window matching the full display dimensions
2. Hide the overlay when in a fullscreen Space (the fullscreen app fills everything, no dimming needed)
3. Listen to `NSWorkspace.activeSpaceDidChangeNotification` to re-evaluate on Space switch
4. Set `.fullScreenAuxiliary` collection behavior on the overlay window

Tell your agent: "Detect fullscreen by comparing the focused app's window bounds to the display dimensions. Hide the overlay in fullscreen Spaces. Use activeSpaceDidChangeNotification to re-evaluate when switching Spaces."

### Phase 8: The Menu Bar UI

Use `MenuBarExtra` with `.window` style (not `.menu` style) for a custom panel:
- `.menu` gives you a flat native menu (text + buttons only)
- `.window` gives you a popover with full SwiftUI controls (sliders, custom views, materials)

Use `.ultraThinMaterial` for glass card backgrounds. Compose sections as VStack with rounded-corner background cards. Build custom slider views with GeometryReader + DragGesture for colored fill tracks.

### Phase 9: Permissions

The app needs Accessibility permission for AXUIElement. To avoid re-prompting:
1. Prompt once on first launch with `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true])`
2. Silently recheck every ~5 seconds with `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false])`
3. Ad-hoc codesign the .app bundle (`codesign --force --sign -`) so macOS remembers the permission across rebuilds

### Common Pitfalls for Agents

| Pitfall | Fix |
|---------|-----|
| Agent uses mask cutout instead of window ordering | Explicitly tell it to use `order(.below, relativeTo:)` at layer 0 |
| Agent uses NSVisualEffectView without customizing blur | Tell it to walk the layer tree and set CAFilter inputRadius |
| Grain looks like TV static | Tell it to use value noise, not hash noise, at very low alpha |
| Agent polls CGWindowListCopyWindowInfo at high frequency | Tell it to use AXObserver + notifications |
| Shake triggers on normal mouse movement | Tell it to require sustained shaking (300ms after threshold) |
| Accessibility re-prompts on every rebuild | Tell it to codesign the .app bundle |
| Swift 6.2 concurrency errors with CVDisplayLink | Tell it to use Timer instead of CVDisplayLink for MainActor types |
| Overlay fights with other overlay apps | Overlay must be at layer 0 and properly ordered |

## Related

- [saturday-club/hocus-pocus](https://github.com/saturday-club/hocus-pocus) -- this repo
- [Monocle](https://heyimo.com/monocle) -- the commercial app that inspired this project
- [AutoRaise](https://github.com/sbmpost/AutoRaise) -- reference for CG/AX window targeting (GPL-2.0, not used as base)

## License

Research project. Not affiliated with Monocle or its developers.
