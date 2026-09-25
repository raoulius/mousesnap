<p align="center">
  <img src="AppIcon.png" width="128" alt="MouseSnap icon">
</p>

<h1 align="center">MouseSnap</h1>

<p align="center">
  Jump your cursor between monitors with a keyboard shortcut.<br>
  A tiny menu bar app for multi-monitor Macs.
</p>

---

## Why

With two, three or more displays, getting the cursor to another screen means a long drag across your desk. Worse, you lose track of which screen it's on. MouseSnap gives each monitor its own hotkey:

- **⌃⌥1** moves the cursor to the center of your leftmost monitor.
- **⌃⌥2** moves it to the center of the next one.
- And so on, up to 9 monitors.

The cursor always lands in the middle of the screen, so you know exactly where it is. When you jump to a different monitor, MouseSnap also clicks once where the cursor lands, so the app there is focused and ready to type into.

MouseSnap is built for multi-monitor setups. With a single display, it has nothing to jump between.

## Features

- **One hotkey per monitor:** `modifier + 1…9` jumps to monitor 1–9, numbered left to right like your physical layout.
- **Works across mixed setups:** different resolutions, scaling and arrangements, including monitors above or below each other.
- **Choose the modifier:** ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⇧.
- **Menu bar only:** no Dock icon and no windows.
- **Monitor list:** the menu shows your connected displays; click one to snap there.
- **Start at Login:** one click in the menu.
- **Focus follows the jump:** a single click on arrival focuses the app on the new monitor. This needs Accessibility permission, which macOS asks for on first launch. Without it, the cursor still moves but nothing is clicked.
- **Small:** a single Swift file, no dependencies, about 80 KB.

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`) to build

## Install

```bash
git clone https://github.com/raoulius/mousesnap.git
cd mousesnap
./build.sh
cp -R MouseSnap.app /Applications/
open /Applications/MouseSnap.app
```

Then turn on **Start at Login** from the menu bar icon.

## Usage

| Shortcut | Action |
| --- | --- |
| `⌃⌥1` | Snap to the center of the leftmost monitor |
| `⌃⌥2` | Snap to the center of the next monitor to the right |
| … | … |
| `⌃⌥9` | Snap to the center of monitor 9 |

To use a different modifier, open **Shortcut** in the menu bar icon's menu.

Monitors are ordered by position, left to right (ties are broken top to bottom). Rearranging displays in System Settings → Displays changes the numbering.

## How it works

- Hotkeys use Carbon's `RegisterEventHotKey`, which works system-wide without Accessibility permission.
- The cursor moves with `CGWarpMouseCursorPosition`.
- The click on arrival is a posted `CGEvent` mouse down/up, which needs Accessibility permission. `build.sh` signs ad hoc, so after a rebuild macOS may stop honoring the old grant: remove MouseSnap under System Settings → Privacy & Security → Accessibility and add it again.
- Start at Login uses `SMAppService`.

## Building the icon

The icon is drawn in code. To regenerate `AppIcon.icns` and `AppIcon.png`:

```bash
swift icon.swift
```

## Project layout

```
main.swift    the app
icon.swift    generates the app icon
build.sh      compiles and bundles MouseSnap.app (ad-hoc signed)
```
