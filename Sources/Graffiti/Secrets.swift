// Spots passwords and keys so they show as dots, never get saved, and clear after a minute.

import Foundation

enum Secrets {
    private static let patterns: [NSRegularExpression] = [
        #"sk-[A-Za-z0-9_\-]{20,}"#,
        #"sk_(live|test)_[A-Za-z0-9]{16,}"#, #"rk_live_[A-Za-z0-9]{16,}"#,
        #"gh[pousr]_[A-Za-z0-9]{30,}"#, #"github_pat_[A-Za-z0-9_]{40,}"#,
        #"xox[abprs]-[A-Za-z0-9\-]{10,}"#,
        #"AKIA[0-9A-Z]{16}"#,
        #"sb_secret_[A-Za-z0-9_\-]{10,}"#,
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
        #"eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"#,
        #"(?m)^[A-Z][A-Z0-9_]{2,}=['"]?[^\s'"]{12,}['"]?$"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    static func looksSecret(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        if patterns.contains(where: { $0.firstMatch(in: s, range: range) != nil }) { return true }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (24...200).contains(t.count), !t.contains(" "), !t.contains("\n"),
              !t.contains("://"), !t.contains("/") else { return false }
        let hasUpper = t.contains(where: \.isUppercase), hasLower = t.contains(where: \.isLowercase)
        let hasDigit = t.contains(where: \.isNumber)
        return hasUpper && hasLower && hasDigit
    }
}
