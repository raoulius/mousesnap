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
    if changingMonitor { click(at: p) }
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

final class App: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let defaults = UserDefaults.standard
    var hotKeys: [EventHotKeyRef] = []

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

        menu.addItem(NSMenuItem.sectionHeader(title: "Monitors"))
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
        add(to: menu, "Quit MouseSnap", #selector(NSApplication.terminate(_:)), key: "q").target = NSApp
    }

    @discardableResult
    func add(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", on: Bool = false) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        item.state = on ? .on : .off
        return item
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
