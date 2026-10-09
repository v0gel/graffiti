// Lets agents read the wall with the graffiti command, but only if you turn it on. Secrets never go out.

import AppKit
import Darwin

enum AgentBridge {
    static var enabled: Bool { UserDefaults.standard.bool(forKey: "agentRead") }

    static var socketPath: String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Graffiti")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        return dir.appendingPathComponent("wall.sock").path
    }

    static let usage = """
    graffiti            list the wall
    graffiti 2 4        print clips 2 and 4 (H for the held clip)
    """

    static func isClientCall(_ args: [String]) -> Bool {
        if (args.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "") == "graffiti" { return true }
        guard args.count > 1 else { return false }
        let a = args[1]
        return a == "list" || a == "help" || a == "--help" || a.uppercased() == "H" || Int(a) != nil
    }

    // MARK: the graffiti command

    static func runClient(_ args: [String]) -> Int32 {
        let args = args.count > 1 ? args : args + ["list"]
        if args[1] == "help" || args[1] == "--help" { print(usage); return 0 }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0, connectTo(fd, socketPath) else {
            print("Graffiti isn't sharing the wall. Open Graffiti and turn on \"Let Agents Read the Wall\" in its menu.")
            return 1
        }
        let request = (args[1] == "list" ? "list" : "get " + args.dropFirst().joined(separator: " ")) + "\n"
        _ = request.withCString { write(fd, $0, strlen($0)) }
        var out = Data(), buf = [UInt8](repeating: 0, count: 65536)
        while true { let n = read(fd, &buf, buf.count); if n <= 0 { break }; out.append(buf, count: n) }
        close(fd)
        print(String(data: out, encoding: .utf8) ?? "", terminator: "")
        return 0
    }

    private static func connectTo(_ fd: Int32, _ path: String) -> Bool {
        var addr = sockaddr_un(); addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { p in
            path.utf8CString.withUnsafeBytes { src in p.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(p.count - 1))) }
        }
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) } == 0
        }
    }

    // MARK: inside the app

    private static var listener: Int32 = -1

    static func start(store: ClipStore) {
        guard enabled, listener < 0 else { return }
        let path = socketPath
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = sockaddr_un(); addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { p in
            path.utf8CString.withUnsafeBytes { src in p.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(p.count - 1))) }
        }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, listen(fd, 4) == 0 else { close(fd); return }
        chmod(path, 0o600)
        listener = fd
        installCommand()
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler {
            let c = accept(fd, nil, nil)
            guard c >= 0 else { return }
            var buf = [UInt8](repeating: 0, count: 1024)
            let n = read(c, &buf, buf.count)
            let req = n > 0 ? String(decoding: buf[0..<n], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let reply = DispatchQueue.main.sync { answer(req, store: store) }
            reply.utf8CString.withUnsafeBufferPointer { p in _ = write(c, p.baseAddress, p.count - 1) }
            close(c)
        }
        src.resume()
        source = src
    }

    private static let queue = DispatchQueue(label: "graffiti.agent-bridge")
    private static var source: DispatchSourceRead?

    static func stop() {
        guard listener >= 0 else { return }
        source?.cancel(); source = nil
        close(listener); listener = -1
        unlink(socketPath)
    }

    private static func installCommand() {
        let bin = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")
        try? FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let link = bin.appendingPathComponent("graffiti").path
        try? FileManager.default.removeItem(atPath: link)
        try? FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: Bundle.main.executablePath ?? "")
    }

    // MARK: what it sends back

    private static func answer(_ req: String, store: ClipStore) -> String {
        if req == "list" {
            var lines: [String] = []
            if let h = store.held { lines.append("H  \(store.heldName.isEmpty ? "Held" : store.heldName): \(oneLine(h))") }
            for (i, c) in store.clips.enumerated() { lines.append("\(i == 9 ? 0 : i + 1)  \(oneLine(c))") }
            return lines.isEmpty ? "The wall is empty.\n" : lines.joined(separator: "\n") + "\n"
        }
        guard req.hasPrefix("get ") else { return usage + "\n" }
        var out: [String] = []
        for token in req.dropFirst(4).split(separator: " ") {
            let key = String(token)
            let clip: Clip?
            if key.uppercased() == "H" { clip = store.held }
            else if let n = Int(key) {
                let i = n == 0 ? 9 : n - 1
                clip = i >= 0 && i < store.clips.count ? store.clips[i] : nil
            } else { clip = nil }
            guard let c = clip else { out.append("--- \(key): no such clip"); continue }
            out.append("--- \(key)  (from \(c.sourceApp))\n" + full(c, label: key))
        }
        return out.joined(separator: "\n\n") + "\n"
    }

    private static func oneLine(_ c: Clip) -> String {
        if c.isSecret { return "[secret, not shared]" }
        switch c.kind {
        case .text(let s): return String(s.split(separator: "\n").first ?? "").prefix(90) + ""
        case .rich(let s, _, let n): return String(s.split(separator: "\n").first ?? "").prefix(70) + " (+\(n) image\(n == 1 ? "" : "s"))"
        case .image: return "[image]"
        case .files(let u): return "[files] " + u.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private static func full(_ c: Clip, label: String) -> String {
        if c.isSecret { return "[secret, not shared]" }
        switch c.kind {
        case .text(let s): return s
        case .files(let u): return u.map(\.path).joined(separator: "\n")
        case .image, .rich:
            var parts: [String] = []
            if let t = c.textForAttach { parts.append(t) }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("graffiti-share")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (i, png) in c.imagesForAttach().enumerated() {
                let f = dir.appendingPathComponent("clip-\(label)-\(i + 1).png")
                try? png.write(to: f)
                parts.append("[image] \(f.path)")
            }
            return parts.joined(separator: "\n")
        }
    }
}
