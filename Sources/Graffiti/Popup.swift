// The wall itself. ⌃⌘V pops it up wherever you're typing.

import AppKit
import SwiftUI

final class PopupPanel: NSPanel {
    var onPick: ((Int, Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onHeld: ((Bool) -> Void)?
    var onHold: ((Int) -> Void)?
    var selected = 0 { didSet { refresh?() } }
    var count = 0
    var refresh: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
                   styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titleVisibility = .hidden; titlebarAppearsTransparent = true
        isMovableByWindowBackground = true; level = .popUpMenu
        hidesOnDeactivate = false; isReleasedWhenClosed = false
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    override var canBecomeKey: Bool { true }

    private static let digits: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 9]
    func handle(keyCode: UInt16, shift: Bool) -> Bool {
        if let i = Self.digits[keyCode] { if i < count { onPick?(i, shift) }; return true }
        switch keyCode {
        case 53: onCancel?(); return true
        case 4: if shift { if count > 0 { onHold?(selected) } } else { onHeld?(false) }; return true
        case 125: selected = min(count - 1, selected + 1); return true
        case 126: selected = max(0, selected - 1); return true
        case 36, 76: if count > 0 { onPick?(selected, shift) }; return true
        default: return false
        }
    }
    override func keyDown(with e: NSEvent) {
        if !handle(keyCode: e.keyCode, shift: e.modifierFlags.contains(.shift)) { super.keyDown(with: e) }
    }
}

struct PopupView: View {
    static let header: NSImage? = {
        guard let url = Bundle.main.url(forResource: "Header@2x", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 180, height: 22); img.isTemplate = true
        return img
    }()
    let clips: [Clip]
    let selected: Int
    let expiry: TimeInterval
    let held: Clip?
    let heldName: String
    let pick: (Int, Bool) -> Void
    let pickHeld: (Bool) -> Void
    let hold: (Int) -> Void
    let renameHeld: () -> Void
    let clearHeld: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let header = Self.header {
                    Image(nsImage: header).renderingMode(.template).foregroundStyle(.primary)
                } else {
                    Text("GRAFFITI").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("1-9, 0 paste · H held · ⇧ clean · esc").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)
            if let held {
                HeldRow(clip: held, name: heldName, clear: clearHeld)
                    .contentShape(Rectangle())
                    .onTapGesture { pickHeld(NSEvent.modifierFlags.contains(.shift)) }
                    .contextMenu {
                        Button("Rename…", action: renameHeld)
                        Button("Clear", action: clearHeld)
                    }
                Divider().padding(.horizontal, 12)
            }
            if clips.isEmpty {
                Text("The wall is empty. Copy something.").foregroundStyle(.secondary).padding(16)
            }
            ForEach(Array(clips.enumerated()), id: \.offset) { i, clip in
                Row(index: i, clip: clip, selected: i == selected, expiry: expiry, hold: { hold(i) })
                    .contentShape(Rectangle())
                    .onTapGesture { pick(i, NSEvent.modifierFlags.contains(.shift)) }
                    .contextMenu {
                        if !clip.isSecret { Button("Hold…") { hold(i) } }
                    }
            }
        }
        .padding(.bottom, 6)
        .frame(width: 440)
    }
}

private struct HeldRow: View {
    let clip: Clip, name: String, clear: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("H")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.orange))
                .foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Held" : name).font(.system(size: 12, weight: .semibold))
                Text(summary).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: clear) { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                .buttonStyle(.plain).help("Clear the held clip")
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.orange.opacity(0.08))
    }

    private var summary: String {
        switch clip.kind {
        case .text(let s): return s.split(separator: "\n").first.map(String.init) ?? ""
        case .rich(let s, _, let n): return (s.split(separator: "\n").first.map(String.init) ?? "") + " · \(n) image\(n == 1 ? "" : "s")"
        case .image: return "Image from \(clip.sourceApp)"
        case .files(let u): return u.map(\.lastPathComponent).joined(separator: ", ")
        }
    }
}

private struct Row: View {
    let index: Int, clip: Clip, selected: Bool, expiry: TimeInterval
    var hold: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(index == 9 ? "0" : "\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(selected ? Color.accentColor : Color.secondary.opacity(0.18)))
                .foregroundStyle(selected ? Color.white : Color.primary)
            VStack(alignment: .leading, spacing: 3) {
                preview
                Text(footer).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let hold, !clip.isSecret {
                Button(action: hold) {
                    Image(systemName: "pin").font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Hold this clip")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    @ViewBuilder private var preview: some View {
        switch clip.kind {
        case .text(let s) where clip.isSecret:
            Text("•••••••••••• secret").font(.system(size: 12, design: .monospaced)).foregroundStyle(.orange)
        case .text(let s):
            Text(Self.head(s))
                .font(looksLikeCode(s) ? .system(size: 11, design: .monospaced) : .system(size: 12))
                .lineLimit(6).truncationMode(.tail)
        case .rich(let s, let images, let count):
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.head(s, lines: 3)).font(.system(size: 12)).lineLimit(4)
                HStack(spacing: 4) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, d in
                        if let img = NSImage(data: d) {
                            Image(nsImage: img).resizable().scaledToFill().frame(width: 54, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text("\(count) image\(count == 1 ? "" : "s")").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary).padding(.leading, images.isEmpty ? 0 : 4)
                }
            }
        case .image(let d):
            if let img = NSImage(data: d) {
                Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: 380, maxHeight: 90, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        case .files(let urls):
            if urls.count == 1, let img = clip.fileThumbnail.flatMap(NSImage.init(data:)) ?? NSImage(contentsOf: urls[0]), img.isValid {
                VStack(alignment: .leading, spacing: 2) {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: 380, maxHeight: 90, alignment: .leading)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text(urls[0].lastPathComponent).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: urls[0].path)).resizable().frame(width: 22, height: 22)
                    Text(urls.map(\.lastPathComponent).joined(separator: ", ")).font(.system(size: 12)).lineLimit(2)
                }
            }
        }
    }

    static func head(_ s: String, lines n: Int = 5) -> String {
        var lines: [String] = []
        for l in s.components(separatedBy: "\n") {
            let blank = l.trimmingCharacters(in: .whitespaces).isEmpty
            if blank && (lines.isEmpty || lines.last == "") { continue }
            lines.append(blank ? "" : l)
        }
        while lines.last == "" { lines.removeLast() }
        let shown = lines.prefix(n).joined(separator: "\n")
        return lines.count > n ? shown + "\n… \(lines.count - n) more lines" : shown
    }

    private var footer: String {
        let ago = Int(Date().timeIntervalSince(clip.capturedAt))
        let when = ago < 60 ? "\(ago)s ago" : ago < 3600 ? "\(ago / 60)m ago" : "\(ago / 3600)h ago"
        var f = "\(clip.sourceApp) · \(when)"
        if clip.isSecret { f += " · clears in \(max(0, Int(expiry) - ago))s" }
        if case .text(let s) = clip.kind, !clip.isSecret { f += " · \(s.count) chars" }
        return f
    }

    private func looksLikeCode(_ s: String) -> Bool {
        let signals = ["{", "}", ";", "=>", "$ ", "&&", "()", "def ", "func ", "const ", "import ", "</", "git ", "cd "]
        return signals.contains(where: s.contains) || s.contains("\n  ")
    }
}
