// Keeps your wall across an update restart. Written to your Mac for a moment, then deleted.

import Foundation

enum WallHandoff {
    private struct Saved: Codable {
        var kind: String
        var text: String?
        var data: Data?
        var paths: [String]?
        var images: [Data]?
        var count: Int?
        var snapshot: [[String: Data]]
        var sourceApp: String
        var sourceBundle: String?
    }
    private struct Wall: Codable { var clips: [Saved]; var held: Saved?; var heldName: String }

    private static var file: URL {
        URL(fileURLWithPath: AgentBridge.socketPath).deletingLastPathComponent().appendingPathComponent("restart.plist")
    }

    static func save(_ store: ClipStore) {
        func pack(_ c: Clip) -> Saved? {
            if c.isSecret { return nil }
            switch c.kind {
            case .text(let s): return Saved(kind: "text", text: s, snapshot: c.snapshot, sourceApp: c.sourceApp, sourceBundle: c.sourceBundle)
            case .image(let d): return Saved(kind: "image", data: d, snapshot: c.snapshot, sourceApp: c.sourceApp, sourceBundle: c.sourceBundle)
            case .files(let u): return Saved(kind: "files", paths: u.map(\.path), snapshot: c.snapshot, sourceApp: c.sourceApp, sourceBundle: c.sourceBundle)
            case .rich(let s, let i, let n): return Saved(kind: "rich", text: s, images: i, count: n, snapshot: c.snapshot, sourceApp: c.sourceApp, sourceBundle: c.sourceBundle)
            }
        }
        let wall = Wall(clips: store.clips.compactMap(pack), held: store.held.flatMap(pack), heldName: store.heldName)
        guard let data = try? PropertyListEncoder().encode(wall) else { return }
        FileManager.default.createFile(atPath: file.path, contents: data, attributes: [.posixPermissions: 0o600])
    }

    static func restore(into store: ClipStore) {
        defer { try? FileManager.default.removeItem(at: file) }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
              let mod = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mod) < 120,
              let data = try? Data(contentsOf: file),
              let wall = try? PropertyListDecoder().decode(Wall.self, from: data) else { return }
        func unpack(_ s: Saved) -> Clip? {
            let kind: Clip.Kind
            switch s.kind {
            case "text": kind = .text(s.text ?? "")
            case "image": guard let d = s.data else { return nil }; kind = .image(d)
            case "files": kind = .files((s.paths ?? []).map { URL(fileURLWithPath: $0) })
            case "rich": kind = .rich(text: s.text ?? "", images: s.images ?? [], imageCount: s.count ?? 0)
            default: return nil
            }
            return Clip(kind: kind, snapshot: s.snapshot, sourceApp: s.sourceApp, sourceBundle: s.sourceBundle,
                        isSecret: false, changeCount: -1)
        }
        store.load(clips: wall.clips.compactMap(unpack), held: wall.held.flatMap(unpack), heldName: wall.heldName)
    }
}
