import Foundation

extension ClipboardTransform {
    // MARK: - Case / whitespace

    nonisolated static func lowercase(_ s: String) -> String { s.lowercased() }
    nonisolated static func uppercase(_ s: String) -> String { s.uppercased() }
    nonisolated static func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    nonisolated static func lowercaseTrimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    nonisolated static func slugify(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        let chars = Array(trimmed)
        for (i, ch) in chars.enumerated() {
            if ch.isLetter || ch.isNumber {
                // Insert hyphen before uppercase that follows lowercase/number (camelCase handling)
                if ch.isUppercase && i > 0 && (chars[i - 1].isLowercase || chars[i - 1].isNumber) {
                    if result.last != "-" { result.append("-") }
                }
                result.append(ch.lowercased())
            } else if !result.isEmpty && result.last != "-" {
                // Non-alphanumeric becomes hyphen
                result.append("-")
            }
        }
        // Clean up: remove leading/trailing hyphens and collapse consecutive hyphens
        while result.first == "-" { result.removeFirst() }
        while result.last == "-" { result.removeLast() }
        return result.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
    }

    nonisolated static func titleCase(_ s: String) -> String {
        s.lowercased().capitalized
    }

    nonisolated static func sentenceCase(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return s }
        return t.prefix(1).uppercased() + t.dropFirst().lowercased()
    }

    nonisolated static func camelCase(_ s: String) -> String {
        let words = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return s }
        let first = words[0].lowercased()
        let rest = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return first + rest.joined()
    }

    nonisolated static func pascalCase(_ s: String) -> String {
        let words = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }

    nonisolated static func snakeCase(_ s: String) -> String {
        var result = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            if ch.isLetter || ch.isNumber {
                if ch.isUppercase && i > 0 && (chars[i - 1].isLowercase || chars[i - 1].isNumber) {
                    if result.last != "_" { result.append("_") }
                }
                result.append(ch.lowercased())
            } else if !result.isEmpty && result.last != "_" {
                result.append("_")
            }
        }
        while result.last == "_" { result.removeLast() }
        return result
    }

    nonisolated static func constCase(_ s: String) -> String {
        snakeCase(s).uppercased()
    }

    // MARK: - Quote escaping

    nonisolated static func escapeDoubleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    nonisolated static func unescapeDoubleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    nonisolated static func escapeSingleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    nonisolated static func unescapeSingleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    nonisolated static func escapeBackslashes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
    }

    nonisolated static func unescapeBackslashes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\\")
    }

    nonisolated static func escapeDollar(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    nonisolated static func unescapeDollar(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\$", with: "$")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    // MARK: - Line tools

    nonisolated static func windowsNewlinesToUnix(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    nonisolated static func sortLines(_ s: String) -> String {
        s.components(separatedBy: .newlines).sorted().joined(separator: "\n")
    }

    nonisolated static func deduplicateLines(_ s: String) -> String {
        var seen = Set<String>()
        return s.components(separatedBy: .newlines)
            .filter { seen.insert($0).inserted }
            .joined(separator: "\n")
    }

    nonisolated static func sortAndDeduplicateLines(_ s: String) -> String {
        var seen = Set<String>()
        return s.components(separatedBy: .newlines)
            .sorted()
            .filter { seen.insert($0).inserted }
            .joined(separator: "\n")
    }

    nonisolated static func reverseLines(_ s: String) -> String {
        s.components(separatedBy: .newlines).reversed().joined(separator: "\n")
    }

    nonisolated static func shuffleLines(_ s: String) -> String {
        var lines = s.components(separatedBy: .newlines)
        lines.shuffle()
        return lines.joined(separator: "\n")
    }

    /// Default line counts for multi-line operations (Head/Tail/Remove).
    /// Backed by UserDefaults key "MultilineRemoveValues", falling back to sane defaults.
    nonisolated static func multilineRemoveValues() -> [Int] {
        let key = "MultilineRemoveValues"
        let defaults = UserDefaults.standard

        // Allow users to configure via: `defaults write <bundle-id> MultilineRemoveValues -array 1 2 5 10 25 50`
        if let stored = defaults.array(forKey: key) {
            let ints: [Int] = stored.compactMap {
                if let n = $0 as? Int { return n }
                if let s = $0 as? String, let n = Int(s) { return n }
                return nil
            }.filter { $0 > 0 }
            if !ints.isEmpty {
                return ints
            }
        }

        // Fallback defaults shown in the README.
        return [1, 2, 5, 10, 25, 50]
    }

    /// Returns the first `count` lines (like `head`).
    nonisolated static func headLines(_ s: String, count: Int) -> String {
        guard count > 0 else { return "" }
        let lines = s.components(separatedBy: .newlines)
        let k = min(count, lines.count)
        return lines.prefix(k).joined(separator: "\n")
    }

    /// Returns the last `count` lines (like `tail`).
    nonisolated static func tailLines(_ s: String, count: Int) -> String {
        guard count > 0 else { return "" }
        let lines = s.components(separatedBy: .newlines)
        let k = min(count, lines.count)
        return lines.suffix(k).joined(separator: "\n")
    }

    /// Removes the first `count` lines; safe when `count` ≥ total lines.
    nonisolated static func removeFirstLines(_ s: String, count: Int) -> String {
        guard count > 0 else { return s }
        let lines = s.components(separatedBy: .newlines)
        let k = min(count, lines.count)
        return lines.dropFirst(k).joined(separator: "\n")
    }

    /// Removes the last `count` lines; safe when `count` ≥ total lines.
    nonisolated static func removeLastLines(_ s: String, count: Int) -> String {
        guard count > 0 else { return s }
        let lines = s.components(separatedBy: .newlines)
        let k = min(count, lines.count)
        return lines.dropLast(k).joined(separator: "\n")
    }

    nonisolated static func removeEmptyLines(_ s: String) -> String {
        s.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }

    nonisolated static func indentLines(_ s: String) -> String {
        s.components(separatedBy: "\n").map { "\t" + $0 }.joined(separator: "\n")
    }

    nonisolated static func unindentLines(_ s: String) -> String {
        s.components(separatedBy: "\n").map { line in
            line.hasPrefix("\t") ? String(line.dropFirst()) : line
        }.joined(separator: "\n")
    }

    nonisolated static func trimLines(_ s: String) -> String {
        s.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    // MARK: - HTML escaping

    nonisolated static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    nonisolated static func htmlUnescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
