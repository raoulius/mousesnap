import Cocoa
import Carbon
import ServiceManagement
import SwiftUI

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
    // A newer jump replaces (or cancels) a click still waiting on the modifiers.
    pendingClick = changingMonitor && hasAppWindow(at: p) ? (p, Date() + 1.5) : nil
    clickWhenModifiersReleased()
}

// The hotkey fires while its modifiers are still held, so clicking right away would be an
// Option-click (hides the app you came from), Control-click (context menu) and so on.
// Wait until they're released; give up if they're held longer than 1.5 s.
var pendingClick: (point: CGPoint, deadline: Date)?
func clickWhenModifiersReleased() {
    guard let pending = pendingClick else { return }
    let held = CGEventSource.flagsState(.hidSystemState)
        .intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
    if held.isEmpty {
        pendingClick = nil
        click(at: pending.point)
    } else if Date() > pending.deadline {
        pendingClick = nil
    } else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { clickWhenModifiersReleased() }
    }
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
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)
        event?.flags = [] // a plain click, never a modified one
        event?.post(tap: .cghidEventTap)
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
        // The click after a jump needs Accessibility. Ad-hoc builds lose the grant on every update,
        // so explain how to redo it: once per version, only when it isn't working.
        if !AXIsProcessTrusted() && defaults.string(forKey: "permissionHelpShown") != currentVersion {
            defaults.set(currentVersion, forKey: "permissionHelpShown")
            showPermissionHelp()
        }

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
        if !AXIsProcessTrusted() {
            add(to: menu, "⚠︎ Allow Accessibility…", #selector(showPermissionHelp))
            menu.addItem(.separator())
        }
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

    var helpWindow: NSWindow?
    @objc func showPermissionHelp() {
        if helpWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PermissionHelp { [weak self] in
                self?.helpWindow?.close()
            }))
            window.title = "MouseSnap"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            helpWindow = window
        }
        helpWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        helpWindow?.makeKeyAndOrderFront(nil)
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

struct PermissionHelp: View {
    let done: () -> Void
    @State private var trusted = AXIsProcessTrusted()
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn clicking back on").font(.title2.bold())
                    Text("MouseSnap \(currentVersion)").foregroundStyle(.secondary)
                }
            }
            Text("After a jump, MouseSnap clicks the window it lands on so that app is ready to use. That needs Accessibility permission, and macOS doesn't carry it over to a new version of MouseSnap, even if MouseSnap still looks switched on. The cursor still jumps without it.")
                .fixedSize(horizontal: false, vertical: true)

            step(1, "Open Accessibility settings.") {
                Button("Open Accessibility Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            step(2, "Select MouseSnap in the list and click the – button to remove it.") { screenshot("RemoveStep") }
            step(3, "Add MouseSnap back, then switch it on.") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Add MouseSnap Again") {
                        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
                    }
                    screenshot("ToggleStep")
                }
            }

            Divider()
            HStack {
                Label(trusted ? "All set. Clicking works again." : "Waiting for permission…",
                      systemImage: trusted ? "checkmark.circle.fill" : "hourglass")
                    .foregroundStyle(trusted ? .green : .secondary)
                Spacer()
                Button(trusted ? "Done" : "Later", action: done).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onReceive(poll) { _ in trusted = AXIsProcessTrusted() }
    }

    func step(_ n: Int, _ text: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)").font(.headline).frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.2)))
            VStack(alignment: .leading, spacing: 8) {
                Text(text).fixedSize(horizontal: false, vertical: true)
                content()
            }
        }
    }

    // Cropped from System Settings, so only MouseSnap's row shows.
    func screenshot(_ name: String) -> some View {
        Group {
            if let image = Bundle.main.image(forResource: name) {
                Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
