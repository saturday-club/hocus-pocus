# autofocus

`autofocus` is a research-first macOS project aimed at building a Monocle-like focus overlay app from scratch.

The goal is not to copy proprietary code. The goal is to reproduce the behavior cleanly:

- detect the active window reliably
- create per-screen overlay windows
- keep the focused window visually clear
- blur, tint, gray, and grain the rest of the screen
- support ambient and deep focus modes
- expose automation and hotkeys

## Repository Layout

- `docs/monocle_notes.md`: recovered findings from the installed Monocle app
- `docs/reverse_engineering_plan.md`: creative attack plan for the undocumented parts
- `prompts/autofocus_master_prompt.md`: detailed implementation prompt for an agent or coding model
- `scripts/collect_monocle_artifacts.sh`: safe local artifact collector for bundle metadata and strings

## Current Position

What looks straightforward:

- menu bar shell
- per-screen overlays
- hotkeys
- URL automation
- excluded apps
- custom grain shader

What looks hard:

- adjustable native blur radius
- transition polish
- desktop, Finder, popover, and multi-display edge cases

## Build Direction

The default build direction for `autofocus` is:

1. Swift + AppKit menu bar app
2. one overlay window per display
3. active-window polling and reconciliation
4. native blur layer first
5. custom grain shader second
6. gradient ambient mode after the baseline works

## No Constraints whatsoever.


