// Apple Notes hides pictures in its own private format. This digs them out, full size.

import AppKit

enum NotesClip {
    static let type = "com.apple.notes.richtext"

    static func images(from data: Data) -> [Data] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
        var pngs: [Data] = []
        func walk(_ o: Any, _ depth: Int) {
            guard depth < 8 else { return }
            if let d = o as? Data {
                if d.count > 1000, d.starts(with: [0x89, 0x50, 0x4E, 0x47]) { pngs.append(d) }
            } else if let a = o as? [Any] { a.forEach { walk($0, depth + 1) } }
            else if let m = o as? [String: Any] { m.values.forEach { walk($0, depth + 1) } }
        }
        walk(root, 0)
        var seen = Set<Data>(), unique: [(Data, Int, Double)] = []
        for p in pngs where seen.insert(p).inserted {
            guard let r = NSBitmapImageRep(data: p), r.pixelsHigh > 0 else { continue }
            unique.append((p, r.pixelsWide * r.pixelsHigh, Double(r.pixelsWide) / Double(r.pixelsHigh)))
        }
        var kept: [(Data, Int, Double)] = []
        for u in unique {
            if let i = kept.firstIndex(where: { abs($0.2 - u.2) / u.2 < 0.03 }) {
                if u.1 > kept[i].1 { kept[i] = u }
            } else { kept.append(u) }
        }
        return kept.map(\.0)
    }
}
