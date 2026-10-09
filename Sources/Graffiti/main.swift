// The app: the spray can in the menu bar, the menu, the hotkey, and what happens when you pick a clip.

import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = ClipStore()
    let panel = PopupPanel()
    var status: NSStatusItem!
    var hotkey: Hotkey!
    var target: NSRunningApplication?
    let keyTap = KeyTap()
    let updater = Updater()
    var clickMonitor: Any?

    func applicationDidFinishLaunching(_ n: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = Bundle.main.image(forResource: "MenuIcon") ?? NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: nil)
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        status.button?.image = icon
        status.button?.toolTip = "Graffiti (⌃⌘V)"
        let menu = NSMenu(); menu.delegate = self; status.menu = menu

        WallHandoff.restore(into: store)
        Updater.beforeRestart = { [weak self] in if let s = self?.store { WallHandoff.save(s) } }
        store.start()
        updater.start()
        AgentBridge.start(store: store)
        let spec = UserDefaults.standard.string(forKey: "hotkey") ?? "ctrl+cmd+v"
        hotkey = Hotkey(spec: spec) { [weak self] in self?.togglePopup() }

        panel.onPick = { [weak self] i, clean in self?.pick(i, clean: clean) }
        panel.onHeld = { [weak self] clean in self?.pickHeld(clean: clean) }
        panel.onHold = { [weak self] i in self?.holdClip(i) }
        panel.onCancel = { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.hidePopup()
            self.target?.activate()
        }
        firstRun()
    }

    func hidePopup(_ why: String = "") {
        panel.orderOut(nil)
        keyTap.stop(); KeyTap.handler = nil
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }

    func togglePopup() {
        if panel.isVisible { panel.onCancel?(); return }
        target = NSWorkspace.shared.frontmostApplication
        panel.selected = 0
        panel.count = store.clips.count
        let render = { [weak self] in
            guard let self else { return }
            let view = PopupView(clips: self.store.clips, selected: self.panel.selected,
                                 expiry: self.store.secretExpiry, held: self.store.held, heldName: self.store.heldName,
                                 pick: { [weak self] i, c in self?.pick(i, clean: c) },
                                 pickHeld: { [weak self] c in self?.pickHeld(clean: c) },
                                 hold: { [weak self] i in self?.holdClip(i) },
                                 renameHeld: { [weak self] in self?.renameHeld() },
                                 clearHeld: { [weak self] in self?.store.clearHeld(); self?.panel.refresh?() })
            let host = NSHostingView(rootView: view)
            self.panel.contentView = host
            self.panel.setContentSize(host.fittingSize)
        }
        panel.refresh = render
        render()
        let p = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main!
        var origin = NSPoint(x: p.x - 20, y: p.y - panel.frame.height + 20)
        origin.x = min(max(origin.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - panel.frame.width - 8)
        origin.y = min(max(origin.y, screen.visibleFrame.minY + 8), screen.visibleFrame.maxY - panel.frame.height - 8)
        panel.setFrameOrigin(origin)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        KeyTap.handler = { [weak self] code, shift in
            guard let self, self.panel.isVisible, !self.panel.isKeyWindow else { return false }
            return self.panel.handle(keyCode: code, shift: shift)
        }
        keyTap.start()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.panel.onCancel?()
        }
    }

    func pick(_ i: Int, clean: Bool) {
        hidePopup()
        guard i < store.clips.count else { target?.activate(); return }
        paste(store.clips[i], clean: clean)
    }

    func pickHeld(clean: Bool) {
        hidePopup()
        guard let clip = store.held else { target?.activate(); return }
        paste(clip, clean: clean)
    }

    func holdClip(_ i: Int) {
        guard i < store.clips.count else { return }
        let clip = store.clips[i]
        hidePopup()
        let replacing = store.held == nil ? "" : " It replaces the clip you are holding now."
        if let name = Dialog.prompt("Hold this clip", "Give it a name so you can find it. It stays on top of the wall and doesn't count toward the ten." + replacing) {
            store.hold(clip, name: name)
        }
        target?.activate()
    }

    func renameHeld() {
        hidePopup()
        if let name = Dialog.prompt("Rename the held clip", "A short name you'll recognise.", initial: store.heldName) {
            store.rename(name)
        }
        target?.activate()
    }

    func paste(_ clip: Clip, clean: Bool) {
        if clip.isSecret && !Paster.confirmSecret(into: target) { return }
        if !clean, let id = target?.bundleIdentifier, Paster.terminalApps.contains(id) {
            let images = clip.imagesForAttach()
            if !images.isEmpty {
                store.paused = true
                Paster.attach(text: clip.textForAttach, images: images, into: target, pb: NSPasteboard.general) { [weak self] in
                    guard let self else { return }
                    self.store.use(clip, clean: false)
                    self.store.paused = false
                    self.store.resync()
                }
                return
            }
        }
        store.use(clip, clean: clean)
        Paster.paste(into: target)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        target = NSWorkspace.shared.frontmostApplication
        menu.removeAllItems()
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let header = NSMenuItem(title: "Graffiti \(v)  ·  ⌃⌘V", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(withTitle: "About Graffiti", action: #selector(showAbout), keyEquivalent: "").target = self
        if let r = updater.available {
            let up = NSMenuItem(title: "New Update: \(r.version)", action: #selector(installUpdate), keyEquivalent: "")
            up.target = self; menu.addItem(up)
        }
        menu.addItem(.separator())
        if let h = store.held {
            let item = NSMenuItem(title: "H   " + (store.heldName.isEmpty ? menuTitle(h) : store.heldName), action: #selector(menuPickHeld), keyEquivalent: "")
            item.target = self; menu.addItem(item)
            menu.addItem(withTitle: "Clear Held Clip", action: #selector(menuClearHeld), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }
        if store.clips.isEmpty { menu.addItem(withTitle: "The wall is empty", action: nil, keyEquivalent: "") }
        for (i, c) in store.clips.enumerated() {
            let title: String
            switch c.kind {
            case .rich(let s, _, let n): title = String(s.split(separator: "\n").first ?? "").prefix(50) + " (+\(n) images)"
            case .text(let s): title = c.isSecret ? "•••••• secret (\(c.sourceApp))" : String(s.split(separator: "\n").first ?? "").prefix(60) + (s.count > 60 ? "…" : "")
            case .image: title = "Image from \(c.sourceApp)"
            case .files(let u): title = u.map(\.lastPathComponent).joined(separator: ", ")
            }
            let item = NSMenuItem(title: title, action: #selector(menuPick(_:)), keyEquivalent: i == 9 ? "0" : "\(i + 1)")
            item.keyEquivalentModifierMask = []
            item.tag = i; item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let holdable = store.clips.enumerated().filter { !$0.element.isSecret }
        if !holdable.isEmpty {
            let sub = NSMenu()
            for (i, c) in holdable {
                let it = NSMenuItem(title: "\(i == 9 ? 0 : i + 1)   " + menuTitle(c), action: #selector(menuHold(_:)), keyEquivalent: "")
                it.tag = i; it.target = self; sub.addItem(it)
            }
            let holdItem = NSMenuItem(title: "Hold a Clip", action: nil, keyEquivalent: "")
            holdItem.submenu = sub
            menu.addItem(holdItem)
        }
        menu.addItem(withTitle: "Clear the Wall", action: #selector(clear), keyEquivalent: "").target = self
        let agents = NSMenuItem(title: "Let Agents Read the Wall", action: #selector(toggleAgents), keyEquivalent: "")
        agents.state = AgentBridge.enabled ? .on : .off; agents.target = self
        menu.addItem(agents)
        let move = NSMenuItem(title: "Last Pasted Clip to Top", action: #selector(toggleMove), keyEquivalent: "")
        move.state = UserDefaults.standard.bool(forKey: "moveToTopOnPaste") ? .on : .off; move.target = self
        menu.addItem(move)
        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off; login.target = self
        menu.addItem(login)
        let ax = NSMenuItem(title: "Allow Pasting (Accessibility)…", action: #selector(askAX), keyEquivalent: "")
        ax.state = Paster.trusted ? .on : .off; ax.target = self
        menu.addItem(ax)
        menu.addItem(withTitle: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit Graffiti", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
    }

    @objc func menuPick(_ s: NSMenuItem) { pick(s.tag, clean: false) }
    @objc func menuPickHeld() { pickHeld(clean: false) }
    @objc func menuClearHeld() { store.clearHeld() }
    @objc func menuHold(_ s: NSMenuItem) { holdClip(s.tag) }

    func menuTitle(_ c: Clip) -> String {
        switch c.kind {
        case .text(let s): return c.isSecret ? "•••••• secret" : String(String(s.split(separator: "\n").first ?? "").prefix(50))
        case .rich(let s, _, let n): return String(String(s.split(separator: "\n").first ?? "").prefix(40)) + " (+\(n) images)"
        case .image: return "Image from \(c.sourceApp)"
        case .files(let u): return u.map(\.lastPathComponent).joined(separator: ", ")
        }
    }
    @objc func clear() { store.clear() }
    @objc func showAbout() { Dialog.about() }
    @objc func toggleAgents() {
        let on = !AgentBridge.enabled
        UserDefaults.standard.set(on, forKey: "agentRead")
        if on {
            AgentBridge.start(store: store)
            Dialog.show("Agents can read the wall",
                        "An agent on this Mac can now run \"graffiti\" to list your clips, or \"graffiti 2 4\" to read clips 2 and 4. Secrets are never shared. Turn this off any time from the menu.")
        } else { AgentBridge.stop() }
    }
    @objc func checkUpdates() { updater.check(userInitiated: true) }
    @objc func installUpdate() { if let r = updater.available { updater.offer(r) } }
    @objc func toggleMove() {
        let d = UserDefaults.standard
        d.set(!d.bool(forKey: "moveToTopOnPaste"), forKey: "moveToTopOnPaste")
    }
    @objc func askAX() {
        if Paster.trusted {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            Paster.askForAccessibility()
        }
    }
    @objc func toggleLogin() {
        let svc = SMAppService.mainApp
        try? (svc.status == .enabled ? svc.unregister() : svc.register())
    }

    func firstRun() {
        guard !UserDefaults.standard.bool(forKey: "didFirstRun") else { return }
        UserDefaults.standard.set(true, forKey: "didFirstRun")
        let choice = Dialog.show("Graffiti is on your wall",
            "Press ⌃⌘V anywhere to see your last ten copies. Pick one with 1–9 or 0, or hold ⇧ to paste it clean.\n\nTo paste for you, Graffiti needs Accessibility permission. Without it, it puts the clip on the clipboard and you press ⌘V.",
            buttons: ["Allow Pasting and Open at Login", "Not Now"])
        if choice == 0 {
            try? SMAppService.mainApp.register()
            Paster.askForAccessibility()
        }
    }
}

if AgentBridge.isClientCall(CommandLine.arguments) {
    exit(AgentBridge.runClient(CommandLine.arguments))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
