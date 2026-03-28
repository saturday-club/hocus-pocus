# Reverse Engineering Plan

This document is focused on extracting the missing implementation details behind Monocle's blur, overlay, and transition stack without needing source access.

## What We Already Know

- The app owns a `CustomBlurEffectView` subclass of `NSVisualEffectView`
- It also carries a `VariableBlurView`
- It tracks window state with `WindowPoller`
- It manages display overlays with `ScreenOverlayManager`
- It ships a custom Metal shader for grain

The main unknown is not "does Monocle use native blur?" The main unknown is "how is it pushing native blur past the default public controls?"

## Creative Reverse Engineering Angles

## 1. Objective-C metadata mining

Use:

- `otool -ov`
- `nm -m`
- `strings`

Purpose:

- recover class names
- recover ivars
- recover overridden selectors
- recover KVO surfaces

What to look for:

- `observeValueForKeyPath`
- `viewDidMoveToWindow`
- `viewWillDraw`
- `layout`
- `setMaterial:`
- `setBlendingMode:`
- `setState:`

Why it matters:

- if `CustomBlurEffectView` is observing a backdrop object, that strongly suggests the real blur tuning may happen through a private layer or backdrop-owned property reachable through KVC or layer traversal

## 2. Layer tree introspection at runtime

Goal:

- inspect the live layer tree of Monocle's overlay windows

Ideas:

- attach LLDB to Monocle and inspect the overlay window hierarchy
- dump `contentView.layer.sublayers`
- inspect classes and ivars of the backing layers
- inspect whether any layer resembles a backdrop layer or filter host

Useful runtime questions:

- what layer class actually sits under `CustomBlurEffectView`
- does the view own a `CAFilter`
- is there a hidden backdrop layer object
- is `VariableBlurView` a wrapper over a standard effect view or a layer-backed container with a private filter

## 3. KVO and observer target recovery

Since `CustomBlurEffectView` implements `observeValueForKeyPath`, it is likely reacting to:

- appearance changes
- backdrop availability
- internal material/backdrop state

Target experiment:

- identify which key paths are observed
- inspect object classes being observed
- correlate that with blur intensity updates

Possible mechanism:

- Monocle may wait for a private backdrop object to appear, then mutate filter parameters after attachment to a window

## 4. Dynamic selector interception

Even without Frida, we can still design for:

- LLDB breakpoints on Objective-C selectors
- symbolic breakpoints on `-[NSVisualEffectView setMaterial:]`
- symbolic breakpoints on `-[NSVisualEffectView setState:]`
- symbolic breakpoints on `-[NSView viewDidMoveToWindow]` for the custom subclass

What to capture:

- call order during overlay creation
- arguments passed when focus mode changes
- whether the view updates only public material/state or also mutates private layer/filter state later

## 5. Asset and icon correlation

Purpose:

- map visible UI states to underlying modes

What we already recovered:

- active
- active ambient
- excluded
- inactive

This helps reconstruct state transitions and menu bar behavior before code exists.

## 6. Unified log correlation

Goal:

- correlate user actions with internal state changes

Experiments:

- toggle Monocle on and off
- switch between ambient and deep
- change blur radius
- change tint preset
- drag files
- move windows between displays

Observe:

- Metal compilation spikes
- window recreation
- overlay redraw patterns
- state change timing

## 7. Live preference mutation

Monocle persists enough settings to drive experiments externally.

Approach:

- toggle settings in UI
- diff the preferences plist
- map setting names to behavior

Questions to answer:

- which values are persisted immediately
- which are only session values
- whether blur radius is persisted under a different domain when non-default
- whether ambient/deep mode is stored or inferred

## 8. URL automation fuzzing

We already know the documented routes:

- toggle
- on
- off
- mode/toggle
- mode/ambient
- mode/deep
- ignore
- unignore

Creative extension:

- try non-destructive guesses like settings open or preset changes only in a controlled session
- inspect whether unadvertised routes exist

Rule:

- do this carefully and only with reversible actions

## 9. Backdrop and filter hypothesis testing

Primary blur hypotheses:

1. `NSVisualEffectView` plus private backdrop tweaks
2. `NSVisualEffectView` plus `CAFilter` parameter tuning
3. wrapper around an internal or private blur-capable view
4. mixed stack: native blur background plus custom mask/overlay composition above it

To discriminate between them:

- inspect layer classes live
- inspect selector traffic
- inspect whether a `CAFilter` instance appears in the layer tree
- inspect whether blur changes trigger layer replacement or in-place parameter mutation

## 10. Rebuild-by-analogy instead of full decompilation

The fastest path may not be "fully decode Monocle." It may be:

1. isolate what Monocle must be doing
2. build the closest clean replica
3. compare the behavior
4. probe the remaining gap

This is especially true for the blur path.

## Practical Experiments To Run Next

## Experiment A: LLDB attach and inspect overlay windows

Objective:

- identify window classes, view hierarchy, and layer classes for the overlay

Success condition:

- recover the real backing layer/filter chain used by `CustomBlurEffectView`

## Experiment B: controlled preference diffs

Objective:

- map UI controls to stored settings and locate any hidden defaults

Success condition:

- fully recover the settings model for blur, tint, grain, and mode control

## Experiment C: mode transition tracing

Objective:

- understand how ambient and deep differ structurally

Success condition:

- know whether ambient is just a masked overlay, a different window level, a different blur material, or all three

## Experiment D: prototype our own `NSVisualEffectView` subclass

Objective:

- test whether native blur plus custom layer plumbing is enough to approximate Monocle without private APIs

Success condition:

- verify whether the hard problem is truly blur intensity control or instead transition polish and masking

## Recommended Engineering Strategy

- Build a clean prototype while reverse-engineering continues
- Keep undocumented tricks behind isolated wrappers
- Treat the blur-control path as an interchangeable module
- Do not make the entire app depend on one fragile private technique

## Bottom Line

The creative path here is not blind decompilation. It is structured triangulation:

- static metadata
- live layer inspection
- state diffing
- selector tracing
- behavior replication

That gives us the best odds of understanding the undocumented blur behavior well enough to recreate it.
