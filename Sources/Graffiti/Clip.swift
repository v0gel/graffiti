// One copy: text, a picture, files, or text with pictures in it.

import AppKit

final class Clip {
    enum Kind {
        case text(String)
        case image(Data)
        case files([URL])
        case rich(text: String, images: [Data], imageCount: Int)
    }

    let kind: Kind
    let snapshot: [[String: Data]]
    let fileThumbnail: Data?
    let sourceApp: String
    let sourceBundle: String?
    let capturedAt: Date
    let isSecret: Bool
    let changeCount: Int

    init(kind: Kind, snapshot: [[String: Data]] = [], fileThumbnail: Data? = nil, sourceApp: String,
         sourceBundle: String?, isSecret: Bool, changeCount: Int) {
        self.kind = kind; self.snapshot = snapshot; self.fileThumbnail = fileThumbnail
        self.sourceApp = sourceApp; self.sourceBundle = sourceBundle
        self.capturedAt = Date(); self.isSecret = isSecret; self.changeCount = changeCount
    }

    var text: String? {
        switch kind {
        case .text(let s): return s
        case .rich(let s, _, _): return s
        default: return nil
        }
    }

    func sameContent(as other: Clip) -> Bool {
        switch (kind, other.kind) {
        case (.text(let a), .text(let b)): return a == b
        case (.image(let a), .image(let b)): return a == b
        case (.files(let a), .files(let b)): return a == b
        case (.rich(let a, _, let n), .rich(let b, _, let m)): return a == b && n == m
        default: return false
        }
    }

    func imagesForAttach() -> [Data] {
        func png(_ d: Data) -> Data? {
            guard let rep = NSBitmapImageRep(data: d) ?? NSImage(data: d)?.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)) else { return nil }
            return rep.representation(using: .png, properties: [:])
        }
        switch kind {
        case .image(let d):
            return [png(d)].compactMap { $0 }
        case .files(let urls):
            return urls.compactMap { u in
                guard let img = NSImage(contentsOf: u), img.isValid, let t = img.tiffRepresentation else { return nil }
                return png(t)
            }
        case .rich:
            var out: [Data] = []
            for item in snapshot {
                if let notes = item[NotesClip.type] {
                    out += NotesClip.images(from: notes)
                } else if let rtfd = item["com.apple.flat-rtfd"] ?? item["public.rtfd"],
                   let a = NSAttributedString(rtfd: rtfd, documentAttributes: nil) {
                    a.enumerateAttribute(.attachment, in: NSRange(location: 0, length: a.length)) { v, _, _ in
                        if let d = (v as? NSTextAttachment)?.fileWrapper?.regularFileContents, let p = png(d) { out.append(p) }
                    }
                } else if let d = item["public.png"] ?? item["public.tiff"] ?? item["public.jpeg"], let p = png(d) {
                    out.append(p)
                }
            }
            return out
        case .text:
            return []
        }
    }

    var textForAttach: String? {
        guard case .rich(let s, _, _) = kind else { return nil }
        let t = s.replacingOccurrences(of: "\u{FFFC}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    func write(to pb: NSPasteboard, clean: Bool) {
        pb.clearContents()
        if clean, let s = text {
            pb.setString(Cleaner.clean(s), forType: .string)
            return
        }
        if !snapshot.isEmpty {
            let items: [NSPasteboardItem] = snapshot.map { formats in
                let item = NSPasteboardItem()
                for (type, data) in formats { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
                return item
            }
            pb.writeObjects(items)
            return
        }
        switch kind {
        case .text(let s), .rich(let s, _, _):
            pb.setString(s, forType: .string)
            if isSecret { pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) }
        case .image(let d):
            pb.setData(d, forType: .tiff)
        case .files(let urls):
            pb.writeObjects(urls as [NSURL])
        }
    }
}
