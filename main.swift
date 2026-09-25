import Cocoa
import Carbon
import ServiceManagement

// Monitors numbered left to right.
func sortedScreens() -> [NSScreen] {
    NSScreen.screens.sorted { ($0.frame.minX, $0.frame.minY) < ($1.frame.minX, $1.frame.minY) }
}

func snap(_ i: Int) {
    let screens = sortedScreens()
    guard i < screens.count else { return }
    let f = screens[i].frame
    let changingMonitor = !f.contains(NSEvent.mouseLocation)
    // Cocoa origin is bottom-left of the menu-bar screen; CG is top-left.
    let flipH = NSScreen.screens[0].frame.height
    let p = CGPoint(x: f.midX, y: flipH - f.midY)
    CGWarpMouseCursorPosition(p)
    CGAssociateMouseAndMouseCursorPosition(1) // no input freeze after the warp
    // Click so the app under the cursor takes focus, as if you'd clicked it yourself.
    // Needs Accessibility permission; without it macOS drops the events and only the cursor moves.
    if changingMonitor && hasAppWindow(at: p) { click(at: p) }
}

// Clicking bare wallpaper triggers macOS's "Click wallpaper to reveal desktop",
// which slides every window away on all monitors. Only click onto a normal app window.
func hasAppWindow(at p: CGPoint) -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.contains { window in
        guard window[kCGWindowLayer as String] as? Int == 0, // normal app windows, not menu bar/Dock/overlays
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
        return rect.contains(p) // CG window bounds use the same top-left coordinates as p
    }
}

func click(at p: CGPoint) {
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}

let modifierOptions: [(label: String, carbon: Int, cocoa: NSEvent.ModifierFlags)] = [
    ("⌃⌥  Control + Option", controlKey | optionKey, [.control, .option]),
    ("⌃⌘  Control + Command", controlKey | cmdKey, [.control, .command]),
    ("⌥⌘  Option + Command", optionKey | cmdKey, [.option, .command]),
    ("⌃⇧  Control + Shift", controlKey | shiftKey, [.control, .shift]),
]
let digitKeys = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
let latestReleaseAPI = URL(string: "https://api.github.com/repos/raoulius/mousesnap/releases/latest")!

// "1.10.0" > "1.9.2"; a leading "v" on tags is ignored.
func isNewer(_ tag: String, than version: String) -> Bool {
    tag.trimmingCharacters(in: ["v"]).compare(version, options: .numeric) == .orderedDescending
}

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let defaults = UserDefaults.standard
    var hotKeys: [EventHotKeyRef] = []
    var update: (version: String, page: URL)?

    var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled"); registerHotKeys() }
    }
    var modifierIndex: Int {
        get { min(defaults.integer(forKey: "modifier"), modifierOptions.count - 1) }
        set { defaults.set(newValue, forKey: "modifier"); registerHotKeys() }
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "MouseSnap")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        // Asks for Accessibility (needed for the click after a snap); macOS shows nothing once granted.
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            snap(Int(id.id))
            return noErr
        }, 1, &spec, nil, nil)
        registerHotKeys()

        checkForUpdates(manual: false)
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdates(manual: false)
        }
    }

    // Quiet checks only light up the menu item; a manual check always reports back.
    func checkForUpdates(manual: Bool) {
        URLSession.shared.dataTask(with: latestReleaseAPI) { data, _, error in
            struct Release: Decodable { let tag_name: String; let html_url: URL }
            let release = data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
            DispatchQueue.main.async {
                if let release, isNewer(release.tag_name, than: currentVersion) {
                    self.update = (release.tag_name.trimmingCharacters(in: ["v"]), release.html_url)
                    if manual { self.openUpdate() }
                } else if manual {
                    let alert = NSAlert()
                    alert.messageText = release == nil ? "Couldn't check for updates" : "You're up to date"
                    alert.informativeText = release == nil
                        ? (error?.localizedDescription ?? "GitHub didn't return a release.")
                        : "MouseSnap \(currentVersion) is the latest version."
                    NSApp.activate(ignoringOtherApps: true)
                    alert.runModal()
                }
            }
        }.resume()
    }

    func registerHotKeys() {
        hotKeys.forEach { UnregisterEventHotKey($0) }
        hotKeys = []
        statusItem.button?.appearsDisabled = !enabled
        guard enabled else { return }
        for (i, key) in digitKeys.enumerated() {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(key), UInt32(modifierOptions[modifierIndex].carbon),
                                EventHotKeyID(signature: 0x534E4150, id: UInt32(i)), GetApplicationEventTarget(), 0, &ref)
            if let ref { hotKeys.append(ref) }
        }
    }

    // Rebuilt on every open so the monitor list and checkmarks are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(to: menu, "Enable MouseSnap", #selector(toggleEnabled), on: enabled)
        menu.addItem(.separator())

        if #available(macOS 14, *) {
            menu.addItem(.sectionHeader(title: "Monitors"))
        } else {
            menu.addItem(withTitle: "Monitors", action: nil, keyEquivalent: "").isEnabled = false
        }
        for (i, screen) in sortedScreens().prefix(9).enumerated() {
            let item = add(to: menu, screen.localizedName, #selector(snapItem(_:)), key: "\(i + 1)")
            item.keyEquivalentModifierMask = modifierOptions[modifierIndex].cocoa
            item.tag = i
        }
        menu.addItem(.separator())

        let shortcut = NSMenu()
        for (i, option) in modifierOptions.enumerated() {
            add(to: shortcut, option.label + " + 1…9", #selector(pickModifier(_:)), on: i == modifierIndex).tag = i
        }
        menu.addItem(withTitle: "Shortcut", action: nil, keyEquivalent: "").submenu = shortcut
        add(to: menu, "Start at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled)
        menu.addItem(.separator())
        if let update {
            add(to: menu, "Update to v\(update.version)…", #selector(openUpdate))
        } else {
            add(to: menu, "Check for Updates…", #selector(checkNow))
        }
        let version = menu.addItem(withTitle: "Version \(currentVersion)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        add(to: menu, "Quit MouseSnap", #selector(NSApplication.terminate(_:)), key: "q").target = NSApp
    }

    @discardableResult
    func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", on: Bool = false) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc func checkNow() { checkForUpdates(manual: true) }
    @objc func openUpdate() {
        guard let update else { return }
        // Homebrew installs keep a Caskroom entry; those users should upgrade through brew.
        let brewInstalled = ["/opt/homebrew", "/usr/local"].contains {
            FileManager.default.fileExists(atPath: "\($0)/Caskroom/mousesnap")
        }
        guard brewInstalled else { NSWorkspace.shared.open(update.page); return }
        let command = "brew upgrade --cask mousesnap"
        let alert = NSAlert()
        alert.messageText = "MouseSnap \(update.version) is available"
        alert.informativeText = "You installed MouseSnap with Homebrew. To update, run this in Terminal:\n\n\(command)"
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "Release Notes")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(update.page)
        default: break
        }
    }
    @objc func toggleEnabled() { enabled.toggle() }
    @objc func snapItem(_ sender: NSMenuItem) { snap(sender.tag) }
    @objc func pickModifier(_ sender: NSMenuItem) { modifierIndex = sender.tag }
    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
