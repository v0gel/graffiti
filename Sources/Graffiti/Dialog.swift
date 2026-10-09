// Graffiti's own dialogs and About window, so they look the same on every Mac.

import AppKit
import SwiftUI

enum Dialog {
    @discardableResult
    static func show(_ title: String, _ message: String, buttons: [String] = ["OK"]) -> Int {
        var choice = buttons.count - 1
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        let view = DialogView(title: title, message: message, buttons: buttons) { i in
            choice = i
            NSApp.stopModal()
        }
        let host = NSHostingView(rootView: view)
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return choice
    }

    static func prompt(_ title: String, _ message: String, initial: String = "") -> String? {
        var result: String?
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        let host = NSHostingView(rootView: PromptView(title: title, message: message, text: initial) { r in
            result = r
            NSApp.stopModal()
        })
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        return result
    }

    static func about() {
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: AboutView { panel.close() })
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        aboutPanel = panel
    }
    private static var aboutPanel: NSPanel?
}

struct Wordmark: View {
    var body: some View {
        if let img = PopupView.header {
            Image(nsImage: img).renderingMode(.template).foregroundStyle(.primary)
        } else {
            Text("GRAFFITI").font(.system(size: 18, weight: .heavy))
        }
    }
}

private struct DialogView: View {
    let title: String, message: String, buttons: [String]
    let pick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Wordmark()
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                ForEach(Array(buttons.enumerated()).reversed(), id: \.offset) { i, label in
                    Button(label) { pick(i) }
                        .keyboardShortcut(i == 0 ? .defaultAction : .cancelAction)
                        .controlSize(.large)
                }
            }
        }
        .padding(22)
        .frame(width: 380)
    }
}

private struct PromptView: View {
    let title: String, message: String
    @State var text: String
    let done: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Wordmark()
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(.secondary)
            TextField("Name", text: $text).textFieldStyle(.roundedBorder).onSubmit { done(text) }
            HStack {
                Spacer()
                Button("Cancel") { done(nil) }.keyboardShortcut(.cancelAction).controlSize(.large)
                Button("Hold") { done(text) }.keyboardShortcut(.defaultAction).controlSize(.large)
            }
        }
        .padding(22)
        .frame(width: 380)
    }
}

private struct AboutView: View {
    let close: () -> Void
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Wordmark()
                Spacer()
                Text("Version \(version)").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Text("Your last ten copies, on the wall, one key away. Text, code, screenshots, images and files, with a preview of each.")
                .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("How to use it").font(.system(size: 12, weight: .semibold))
                step("⌃⌘V", "Open the wall wherever you are typing.")
                step("1 – 9, 0", "Paste that clip. Or click it.")
                step("⇧ + number", "Paste it clean: plain text, ready for a terminal.")
                step("H", "Paste your held clip. ⇧H holds the selected one.")
                step("esc", "Close the wall.")
            }
            Text("Passwords and keys show as dots, are never saved, and clear themselves after a minute. Your clips never leave your Mac.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Developed by M. Scott Vogel for Kingdom of Id").font(.system(size: 12))
                Text("Designed in Brooklyn ❤️").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction).controlSize(.large) }
        }
        .padding(22)
        .frame(width: 400)
    }

    private func step(_ key: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key).font(.system(size: 11, weight: .semibold, design: .rounded))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)))
                .frame(width: 84, alignment: .leading)
            Text(text).font(.system(size: 12))
        }
    }
}
