// Puts a clip back on the clipboard and presses paste for you. Terminals get pictures as attachments.

import AppKit
import ApplicationServices

enum Paster {
    static let agentApps: Set<String> = [
        "com.todesktop.230313mzl4w4u92",
        "com.microsoft.VSCode", "com.apple.Terminal", "com.googlecode.iterm2",
        "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "com.anthropic.claudefordesktop", "com.openai.chat", "com.openai.codex"
    ]

    static let terminalApps: Set<String> = [
        "com.todesktop.230313mzl4w4u92", "com.microsoft.VSCode", "com.apple.Terminal",
        "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty", "net.kovidgoyal.kitty"
    ]

    static var trusted: Bool { AXIsProcessTrusted() }

    static func key(_ code: CGKeyCode, _ flags: CGEventFlags) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        down?.flags = flags; up?.flags = flags
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }

    static func attach(text: String?, images: [Data], into app: NSRunningApplication?, pb: NSPasteboard, done: @escaping () -> Void) {
        app?.activate()
        guard trusted else { done(); return }
        var steps: [() -> Void] = []
        if let text {
            steps.append { pb.clearContents(); pb.setString(text, forType: .string); key(9, .maskCommand) }
        }
        for img in images {
            steps.append { pb.clearContents(); pb.setData(img, forType: .png); key(9, .maskControl) }
        }
        func run(_ i: Int) {
            guard i < steps.count else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: done); return }
            steps[i]()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { run(i + 1) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { run(0) }
    }

    static func askForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func confirmSecret(into app: NSRunningApplication?) -> Bool {
        guard let id = app?.bundleIdentifier, agentApps.contains(id) else { return true }
        let ok = Dialog.show("Paste a secret into \(app?.localizedName ?? "this app")?", "This looks like a password or key, and \(app?.localizedName ?? "this app") is an app where AI agents read what you paste.", buttons: ["Paste Anyway", "Don't Paste"]) == 0
        app?.activate()
        return ok
    }

    static func paste(into app: NSRunningApplication?) {
        app?.activate()
        guard trusted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
            down?.flags = .maskCommand; up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
        }
    }
}
