// Clean paste: straight quotes, no $ prompts, no leftover markers or indents.

import Foundation

enum Cleaner {
    static func clean(_ input: String) -> String {
        var s = input
        for (a, b) in [("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{2018}", "'"), ("\u{2019}", "'"),
                       ("\u{2013}", "-"), ("\u{2014}", "-"), ("\u{00A0}", " ")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        var lines = s.components(separatedBy: "\n").map { line -> String in
            var l = line
            while l.last == " " || l.last == "\t" { l.removeLast() }
            let indent = String(l.prefix(while: { $0 == " " }))
            var body = l.dropFirst(indent.count)
            for marker in ["⏺", "⎿", "❯", "●"] where body.hasPrefix(marker) {
                body = body.dropFirst(marker.count).drop(while: { $0 == " " })
            }
            l = indent + body
            return l
        }
        let indents = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.prefix(while: { $0 == " " }).count }
        if let common = indents.min(), common > 0 {
            lines = lines.map { $0.count >= common ? String($0.dropFirst(common)) : $0 }
        }
        lines = lines.map { l in
            let t = l.drop(while: { $0 == " " })
            return (t.hasPrefix("$ ") || t.hasPrefix("% ")) ? String(t.dropFirst(2)) : l
        }
        while let f = lines.first, f.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        while let l = lines.last, l.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeLast() }
        return lines.joined(separator: "\n")
    }
}
