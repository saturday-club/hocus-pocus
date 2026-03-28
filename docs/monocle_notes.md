# Monocle Notes

Date of local inspection: 2026-03-28
Installed version inspected: 3.0.3 (build 15)

## High-confidence findings

- Bundle identifier: `dk.heyiam.monocle`
- Menu bar app: `LSUIElement = true`
- URL scheme: `monocle://`
- Update system: Sparkle
- License backend: Gumroad
- Minimum macOS version observed in bundle: `14.6`
- Signed and notarized Developer ID app

## Recovered feature set

- ambient mode
- deep mode
- excluded apps
- global shortcuts
- settings shortcut
- exclude-app shortcut
- URL automation
- shake to toggle
- shift-shake to peek
- grayscale
- tint presets
- system accent tint
- grain intensity
- blur radius
- optional Dock/menu bar auto-hide
- highlight all windows of the active app
- launch at login

## Recovered internal type names

- `CustomBlurEffectView`
- `VariableBlurView`
- `ScreenOverlayManager`
- `WindowPoller`
- `WindowInfo`
- `ExcludedAppsManager`
- `HotKeyManager`
- `LaunchAtLoginManager`
- `LicenseManager`
- `ShakeGestureRecognizer`

## Strong rendering clues

- Monocle subclasses `NSVisualEffectView` directly through `CustomBlurEffectView`
- the binary exposes `material`, `blendingMode`, `state`, `observedBackdrop`, `blurRadius`, and `grayscale`
- the bundled Metal library clearly exposes `grainShader`

Interpretation:

- grain is custom
- blur is likely native macOS visual effect machinery with custom control around it

## Entitlement clues

Observed entitlements include:

- `com.apple.security.app-sandbox`
- `com.apple.security.window-management`
- `com.apple.security.automation.apple-events`
- `com.apple.security.network.client`

Observed temporary exceptions include:

- Apple Events access to Finder and System Events
- WindowServer-related mach lookup exceptions

Interpretation:

- Dock and menu bar auto-hide appears to be implemented with Apple Events via System Events
- window-state tracking likely goes beyond plain app-local AppKit state

## Important local preference clues

Observed keys in local settings:

- `excludedApps`
- `grainIntensity_v2`
- `isOverlayEnabled`
- `isSystemTintEnabled`
- `tintOpacity`
- `tintPresetName`

Decoded excluded apps on the inspected machine:

- Finder
- Digital Color Meter

## AutoRaise takeaway

AutoRaise is a useful reference for:

- `CGWindowListCopyWindowInfo`
- `AXUIElementCopyElementAtPosition`
- AX to `CGWindowID` bridging
- window-under-pointer recovery logic

AutoRaise is not a good base because:

- it is centered on focus/raise behavior, not visual overlays
- it uses private APIs in places
- it is GPL-2.0
