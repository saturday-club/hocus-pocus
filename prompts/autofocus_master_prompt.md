# autofocus Master Prompt

You are building `autofocus`, a native macOS menu bar application inspired by the behavior of Monocle, but implemented from scratch.

The job is not to copy proprietary code, private assets, or exact branding. The job is to recreate the product category and interaction quality:

- the active window remains visually clear
- the rest of the screen is visually softened
- the user can switch between a subtler ambient mode and a stronger deep mode
- the app feels native, fast, and calm

## Primary Goal

Build a working macOS app that:

1. runs as a menu bar utility
2. tracks the active window across displays
3. creates overlay windows per display
4. visually suppresses non-focused screen regions
5. supports blur, tint, grayscale, and grain
6. supports excluded apps
7. supports global shortcuts and URL automation

## Product Requirements

### Core behavior

- Detect the frontmost application and its active window.
- Determine which display contains the active window.
- Keep the target window region visually clear.
- Apply visual suppression outside the target region.
- Support multiple displays.
- Update smoothly as the target window changes, moves, resizes, or disappears.

### Modes

Implement at least two modes:

- `ambient`
  - softer effect
  - more spacious presentation
  - gradient or masked feel is acceptable
- `deep`
  - stronger fullscreen suppression
  - more aggressive focus isolation

### Visual controls

Expose controls for:

- blur amount
- grain intensity
- tint enabled
- tint preset
- tint opacity
- grayscale enabled
- overlay enabled
- same-app grouping toggle

### Interaction controls

Expose:

- toggle overlay shortcut
- toggle mode shortcut
- exclude current app shortcut
- settings shortcut
- URL scheme routes for:
  - toggle
  - on
  - off
  - mode toggle
  - mode ambient
  - mode deep
  - ignore
  - unignore

### Exclusions

Support:

- exclude current app
- persistent excluded app list
- special handling for Finder and desktop interaction

## Non-goals

- no license system yet
- no payment flow
- no updater
- no marketing site
- no telemetry

## Technical Constraints

- Use Swift and AppKit.
- SwiftUI may be used for settings UI if helpful, but overlay behavior should not depend on SwiftUI abstractions.
- Prefer public APIs first.
- If undocumented behavior is needed, isolate it behind minimal, swappable wrappers.
- Do not make the full app depend on one private blur trick.
- Do not use AutoRaise as a codebase base.
- Do not copy Monocle assets, strings, or source.

## Architecture Guidance

Implement these subsystems explicitly.

### 1. App shell

Responsibilities:

- menu bar item
- settings window
- app lifecycle
- launch at login integration later

Suggested types:

- `AppCoordinator`
- `MenuBarController`
- `SettingsWindowController`

### 2. Window detection

Responsibilities:

- poll or observe frontmost app and active window
- recover target window frame
- reconcile changes across displays

Suggested types:

- `WindowPoller`
- `WindowSnapshot`
- `DisplaySnapshot`
- `WindowDetectionCoordinator`

Requirements:

- handle missing windows gracefully
- survive app switches
- survive transient popups
- degrade gracefully when exact active window cannot be recovered

### 3. Overlay system

Responsibilities:

- one overlay window per display
- z-order and level management
- mouse transparency
- animation and transition control

Suggested types:

- `ScreenOverlayManager`
- `OverlayWindowController`
- `OverlayScene`
- `OverlayState`

### 4. Blur/grain/tint composition

Responsibilities:

- clear or minimally affected target region
- suppression outside target region
- blur layer
- tint layer
- grayscale handling
- custom grain layer

Suggested types:

- `CustomBlurEffectView`
- `VariableBlurController`
- `GrainRenderer`
- `OverlayMaskView`
- `TintLayerController`

### 5. Settings and persistence

Suggested types:

- `AppSettings`
- `ExcludedAppsStore`
- `ShortcutStore`

Persist:

- mode
- blur amount
- grain intensity
- grayscale
- tint preset
- tint opacity
- overlay enabled
- excluded apps
- shortcut assignments

## Implementation Plan

### Milestone 1: working skeleton

Deliver:

- menu bar app launches
- settings window opens
- overlay windows can be created per display
- overlay can be toggled on and off

Success criteria:

- app runs stably
- overlay windows ignore mouse events
- no visual glitches when enabling or disabling

### Milestone 2: active window tracking

Deliver:

- frontmost app detection
- active window frame detection
- target region updates when switching apps

Success criteria:

- clear region follows the active window
- basic multi-display correctness

### Milestone 3: deep mode

Deliver:

- strong suppression outside target region
- no grain yet if that blocks progress

Success criteria:

- obvious focus effect
- window switching feels responsive

### Milestone 4: grain and tint

Deliver:

- custom grain layer
- tint presets
- tint opacity
- grayscale toggle

Success criteria:

- effect looks intentional, not muddy
- performance remains acceptable

### Milestone 5: ambient mode

Deliver:

- softer alternative presentation
- gradient or spatial mask behavior

Success criteria:

- visibly distinct from deep mode
- transitions remain stable

### Milestone 6: polish and automation

Deliver:

- excluded apps
- shortcuts
- URL scheme
- same-app grouping toggle

Success criteria:

- practical daily-driver feature set

## Reverse Engineering Guidance

Use the Monocle findings only as behavioral clues.

Known clues:

- Monocle subclasses `NSVisualEffectView`
- it carries `CustomBlurEffectView`, `VariableBlurView`, `WindowPoller`, and `ScreenOverlayManager`
- it uses custom Metal grain
- it likely controls native blur beyond the default public knobs

Translate those clues into clean experiments:

1. first build with plain `NSVisualEffectView`
2. then add masking
3. then add custom grain
4. only after that investigate variable blur control

## Quality Bar

The app should feel:

- quiet
- stable
- native
- intentional

Avoid:

- flashing
- abrupt overlay recreation
- laggy window tracking
- visual dirtiness from bad masks or noisy grain

## Testing Guidance

Test against:

- single display
- dual display
- Finder desktop
- Safari
- Xcode
- Terminal
- apps with sheets and popovers
- fast app switching
- resizing active windows
- moving windows between displays

## Performance Guidance

- minimize full overlay teardown
- update only the regions and displays that changed
- avoid expensive redraws on every tiny event
- isolate grain rendering so it can be tuned or disabled

## Failure Strategy

If exact adjustable native blur proves too fragile:

- ship with a fixed native blur baseline
- make grain, tint, mask shape, and transition polish excellent
- keep the blur-control path modular so it can be upgraded later

## Deliverables

Produce:

1. a runnable Xcode project
2. a menu bar app
3. a settings UI
4. a documented architecture
5. a clear list of public vs fragile implementation pieces

## Final Instruction

Do not get stuck trying to perfectly decode Monocle before building anything.

The right approach is:

1. reproduce the category cleanly
2. isolate the undocumented blur problem
3. compare the result
4. improve only where the gap is real
