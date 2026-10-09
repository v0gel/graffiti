// Updates. Checks once a day, and only installs something signed with my update key and my certificate.

import AppKit
import CryptoKit

final class Updater {
    static let feed = URL(string: UserDefaults.standard.string(forKey: "updateFeed")
                          ?? "https://graffiti-updates.pages.dev/latest.json")!
    private static let publicKey = "IUJTGuWpOcVZQGkOX+dP60BEM2a1cxpx2o/2uxdez+s="

    struct Release: Decodable { let version: String; let url: String; let sha256: String; let signature: String; let notes: String? }

    private(set) var available: Release?
    private(set) var lastError: String?
    var onChange: (() -> Void)?
    static var beforeRestart: (() -> Void)?

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func start() {
        check(userInitiated: false)
        Self.count()
        Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            self?.check(userInitiated: false)
            Self.count()
        }
    }

    // Counts, nothing else: a first install, one check a day, and the version.
    static func count() {
        let d = UserDefaults.standard
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: TimeZone(identifier: "UTC")!, formatOptions: [.withFullDate])
        var kinds: [(String, () -> Void)] = []
        if !d.bool(forKey: "countedInstall") { kinds.append(("install", { d.set(true, forKey: "countedInstall") })) }
        if d.string(forKey: "countedDay") != day { kinds.append(("check", { d.set(day, forKey: "countedDay") })) }
        for (kind, mark) in kinds {
            var c = URLComponents(url: feed.deletingLastPathComponent().appendingPathComponent("api/hit"), resolvingAgainstBaseURL: false)!
            c.queryItems = [URLQueryItem(name: "k", value: kind), URLQueryItem(name: "v", value: current)]
            URLSession.shared.dataTask(with: c.url!) { _, resp, _ in
                if (resp as? HTTPURLResponse)?.statusCode == 204 { DispatchQueue.main.async(execute: mark) }
            }.resume()
        }
    }

    func check(userInitiated: Bool) {
        var req = URLRequest(url: Self.feed); req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let r = try? JSONDecoder().decode(Release.self, from: data) else {
                    self.lastError = err?.localizedDescription ?? "could not read the update feed"
                    if userInitiated { Self.alert("Couldn't check for updates", self.lastError!) }
                    return
                }
                self.lastError = nil
                self.available = Self.newer(r.version, than: Self.current) ? r : nil
                self.onChange?()
                if userInitiated {
                    if let a = self.available { self.offer(a) }
                    else { Self.alert("You're up to date", "Graffiti \(Self.current) is the latest version.") }
                }
            }
        }.resume()
    }

    func offer(_ r: Release) {
        let notes = r.notes ?? ""
        let text = (notes.isEmpty ? "" : notes + "\n\n") + "You have \(Self.current). Your wall is kept."
        if Dialog.show("New Update: Graffiti \(r.version)", text, buttons: ["Install and Restart", "Later"]) == 0 { install(r) }
    }

    func install(_ r: Release) {
        guard let url = URL(string: r.url) else { return }
        URLSession.shared.dataTask(with: url) { data, _, err in
            DispatchQueue.main.async {
                guard let data else { Self.alert("Update failed", err?.localizedDescription ?? "download failed"); return }
                do { try Self.verifyAndReplace(data, r) }
                catch { Self.alert("Update refused", error.localizedDescription) }
            }
        }.resume()
    }

    private struct Fail: LocalizedError { let errorDescription: String? }

    private static func verifyAndReplace(_ zip: Data, _ r: Release) throws {
        let hash = SHA256.hash(data: zip).map { String(format: "%02x", $0) }.joined()
        guard hash == r.sha256 else { throw Fail(errorDescription: "The download does not match its checksum.") }
        guard let pk = Data(base64Encoded: publicKey), let sig = Data(base64Encoded: r.signature),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pk),
              key.isValidSignature(sig, for: zip) else {
            throw Fail(errorDescription: "The download is not signed with the Graffiti update key.")
        }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("graffiti-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let zipURL = work.appendingPathComponent("Graffiti.zip")
        try zip.write(to: zipURL)
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, work.path])
        let newApp = work.appendingPathComponent("Graffiti.app")
        let mine = Bundle.main.bundleURL
        let req = try run("/usr/bin/codesign", ["-d", "-r-", mine.path])
        guard let line = req.split(separator: "\n").first(where: { $0.hasPrefix("designated => ") }) else {
            throw Fail(errorDescription: "Could not read this app's signing requirement.")
        }
        let designated = String(line.dropFirst("designated => ".count))
        do { try run("/usr/bin/codesign", ["--verify", "--deep", "-R=\(designated)", newApp.path]) }
        catch { throw Fail(errorDescription: "The new app is not signed with your Graffiti certificate.") }
        _ = try FileManager.default.replaceItemAt(mine, withItemAt: newApp)
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "sleep 1; open \"\(mine.path)\""]
        try relaunch.run()
        beforeRestart?()
        NSApp.terminate(nil)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String], stderr: Bool = false) throws -> String {
        let p = Process(); p.executableURL = URL(fileURLWithPath: tool); p.arguments = args
        let pipe = Pipe()
        if stderr { p.standardError = pipe; p.standardOutput = Pipe() } else { p.standardOutput = pipe; p.standardError = Pipe() }
        try p.run(); p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard p.terminationStatus == 0 else { throw Fail(errorDescription: "\(tool) failed") }
        return out
    }

    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }

    static func alert(_ title: String, _ text: String) { Dialog.show(title, text) }
}
