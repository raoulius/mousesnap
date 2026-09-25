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

- macOS 13 Ventura or later, Apple silicon or Intel

## Install

### Download

1. Download `MouseSnap.zip` from the [latest release](https://github.com/raoulius/mousesnap/releases/latest).
2. Unzip it and move `MouseSnap.app` to `/Applications`.
3. MouseSnap isn't notarized by Apple, so macOS blocks the first launch. Right-click the app, choose **Open**, then confirm. Alternatively, run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/MouseSnap.app
   ```

### Build from source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/raoulius/mousesnap.git
cd mousesnap
./build.sh
cp -R MouseSnap.app /Applications/
open /Applications/MouseSnap.app
```

Then turn on **Start at Login** from the menu bar icon.

## Updating

MouseSnap checks GitHub for a new release when it launches and once a day after that. When one is available, the menu shows **Update to vX.Y.Z…**, which opens the release page. Download the new zip and replace the app in `/Applications`. You can also check at any time with **Check for Updates…**. The menu shows your installed version at the bottom.

After replacing the app, macOS may stop honoring the Accessibility permission. If the click on arrival stops working, remove MouseSnap under System Settings → Privacy & Security → Accessibility and add it again.

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

## Releasing

Push a version tag:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

The [Release workflow](.github/workflows/release.yml) builds a universal app with that version number, zips it and publishes a GitHub release with `MouseSnap.zip` attached. Installed copies see the new release within a day.

## Building the icon

The icon is drawn in code. To regenerate `AppIcon.icns` and `AppIcon.png`:

```bash
swift icon.swift
```

## Project layout

```
main.swift    the app
icon.swift    generates the app icon
build.sh      compiles and bundles MouseSnap.app (universal, ad-hoc signed)
.github/      release workflow
```
