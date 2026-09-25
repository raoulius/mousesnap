<p align="center">
  <img src="AppIcon.png" width="128" alt="MouseSnap icon">
</p>

<h1 align="center">MouseSnap</h1>

<p align="center">
  Snap your cursor to the center of any monitor with a keyboard shortcut.<br>
  A tiny menu bar app for multi-monitor Macs.
</p>

---

On a big multi-monitor setup, dragging the mouse across screens gets old fast. MouseSnap puts it where you want it with one keystroke: press **⌃⌥1** and the cursor jumps to the center of your first monitor, **⌃⌥2** to the second, and so on.

## Features

- **Global shortcuts:** `modifier + 1…9` jumps to monitor 1–9, numbered left to right.
- **Choose the modifier:** ⌃⌥, ⌃⌘, ⌥⌘ or ⌃⇧.
- **Menu bar only:** no Dock icon and no windows.
- **Monitor list:** the menu shows your connected displays; click one to snap there.
- **Start at Login:** one click in the menu.
- **No permissions needed:** no Accessibility or Input Monitoring prompts.
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
