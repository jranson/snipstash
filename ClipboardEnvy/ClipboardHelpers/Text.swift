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

    /// Default line counts for multiline operations (Head/Tail/Remove).
    /// Backed by UserDefaults key "RemoveLinesValues", falling back to sane defaults.
    nonisolated static func multilineRemoveValues() -> [Int] {
        let key = "RemoveLinesValues"
        let defaults = UserDefaults.standard

        // Allow users to configure via: `defaults write <bundle-id> RemoveLinesValues -array 1 2 5 10 25 50`
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

    nonisolated static func indentLines(_ s: String, indent: String = "\t") -> String {
        s.components(separatedBy: "\n")
            .map { indent + $0 }
            .joined(separator: "\n")
    }

    nonisolated static func unindentLines(_ s: String, indent: String = "\t") -> String {
        s.components(separatedBy: "\n")
            .map { line in
                guard !indent.isEmpty, line.hasPrefix(indent) else { return line }
                return String(line.dropFirst(indent.count))
            }
            .joined(separator: "\n")
    }

    nonisolated static func trimLines(_ s: String) -> String {
        s.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    /// Trims a single trailing comma on each line, if present (ignores whitespace).
    nonisolated static func trimTrailingCommas(_ s: String) -> String {
        s.components(separatedBy: "\n").map { line in
            let trimmedRight = line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            if trimmedRight.hasSuffix(",") {
                var withoutComma = String(trimmedRight.dropLast())
                // Also trim a single preceding space if present (e.g. "b ,  " → "b  ").
                if withoutComma.hasSuffix(" ") {
                    withoutComma.removeLast()
                }
                let trailingWhitespaceRange = line.range(of: "\\s+$", options: .regularExpression)
                let suffix = trailingWhitespaceRange.map { String(line[$0]) } ?? ""
                return withoutComma + suffix
            }
            return line
        }.joined(separator: "\n")
    }

    /// Trims a single trailing semicolon on each line, if present (ignores whitespace).
    nonisolated static func trimTrailingSemicolons(_ s: String) -> String {
        s.components(separatedBy: "\n").map { line in
            let trimmedRight = line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            if trimmedRight.hasSuffix(";") {
                var withoutSemi = String(trimmedRight.dropLast())
                // Also trim a single preceding space if present (e.g. "b ;" → "b").
                if withoutSemi.hasSuffix(" ") {
                    withoutSemi.removeLast()
                }
                let trailingWhitespaceRange = line.range(of: "\\s+$", options: .regularExpression)
                let suffix = trailingWhitespaceRange.map { String(line[$0]) } ?? ""
                return withoutSemi + suffix
            }
            return line
        }.joined(separator: "\n")
    }

    // MARK: - Wrap helpers

    /// Wraps each non-empty line with the given prefix and suffix.
    nonisolated static func wrapLines(_ s: String, prefix: String, suffix: String) -> String {
        s.components(separatedBy: .newlines)
            .map { line in
                guard !line.isEmpty else { return line }
                return prefix + line + suffix
            }
            .joined(separator: "\n")
    }

    /// Built-in wrappers for the Wrap Lines menu.
    /// Each tuple is (label, prefix, suffix).
    nonisolated static func builtinMultilineWrappers() -> [(label: String, prefix: String, suffix: String)] {
        [
            ("\"line\"", "\"", "\""),
            ("`line`", "`", "`"),
            ("'line'", "'", "'"),
            ("\"line\",", "\"", "\","),
            ("`line`,", "`", "`,"),
            ("'line',", "'", "',"),
            ("[line]", "[", "]"),
            ("[line],", "[", "],"),
            ("- line", "- ", ""),
            ("• line", "• ", ""),
            ("* line", "* ", ""),
            ("# line", "# ", ""),
            ("// line", "// ", ""),
        ]
    }

    /// Custom wrappers backed by UserDefaults key `TextLineWrappers`.
    /// Stored as a dictionary of label → "prefix|suffix".
    nonisolated static func customMultilineWrappers() -> [(label: String, prefix: String, suffix: String)] {
        let key = "TextLineWrappers"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }

        return dict.keys.sorted().compactMap { label in
            guard let spec = dict[label] else { return nil }
            let parts = spec.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let prefix = String(parts[0])
            let suffix = String(parts[1])
            return (label: label, prefix: prefix, suffix: suffix)
        }
    }

    // MARK: - Line frequency helpers

    /// Removes lines that do not have at least one duplicate.
    nonisolated static func removeUniqueLines(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var counts: [String: Int] = [:]
        for line in lines {
            counts[line, default: 0] += 1
        }
        let result = lines.filter { counts[$0, default: 0] > 1 }
        return result.joined(separator: "\n")
    }

    /// Keeps only lines that appear exactly once.
    nonisolated static func keepUniqueLines(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var counts: [String: Int] = [:]
        for line in lines {
            counts[line, default: 0] += 1
        }
        let result = lines.filter { counts[$0, default: 0] == 1 }
        return result.joined(separator: "\n")
    }

    /// Keeps only lines that have at least one duplicate, with duplicates collapsed (equivalent to Remove Unique + Deduplicate).
    nonisolated static func keepDuplicateLinesCollapsed(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var counts: [String: Int] = [:]
        for line in lines {
            counts[line, default: 0] += 1
        }
        let duplicates = lines.filter { counts[$0, default: 0] > 1 }
        var seen = Set<String>()
        let deduped = duplicates.filter { seen.insert($0).inserted }
        return deduped.joined(separator: "\n")
    }

    /// Sorts lines by frequency of appearance (ascending); preserves relative order within same-frequency groups.
    nonisolated static func sortLinesByFrequencyAscending(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var counts: [String: Int] = [:]
        for line in lines {
            counts[line, default: 0] += 1
        }
        let indexed = Array(lines.enumerated())
        let sorted = indexed.sorted { a, b in
            let ca = counts[a.element, default: 0]
            let cb = counts[b.element, default: 0]
            if ca != cb { return ca < cb }
            return a.offset < b.offset
        }
        return sorted.map { $0.element }.joined(separator: "\n")
    }

    /// Sorts lines by frequency of appearance (descending); preserves relative order within same-frequency groups.
    nonisolated static func sortLinesByFrequencyDescending(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var counts: [String: Int] = [:]
        for line in lines {
            counts[line, default: 0] += 1
        }
        let indexed = Array(lines.enumerated())
        let sorted = indexed.sorted { a, b in
            let ca = counts[a.element, default: 0]
            let cb = counts[b.element, default: 0]
            if ca != cb { return ca > cb }
            return a.offset < b.offset
        }
        return sorted.map { $0.element }.joined(separator: "\n")
    }

    /// Unwraps lines by removing a leading prefix and/or trailing suffix if present.
    /// If only one matches, it is removed independently.
    nonisolated static func unwrapLines(_ s: String, prefix: String, suffix: String) -> String {
        s.components(separatedBy: .newlines).map { line in
            var result = line
            if !prefix.isEmpty, result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
            }
            if !suffix.isEmpty, result.hasSuffix(suffix) {
                result.removeLast(suffix.count)
            }
            return result
        }.joined(separator: "\n")
    }

    // MARK: - Join / Split helpers

    /// Joins non-empty lines using the provided delimiter. Empty input yields an empty string.
    nonisolated static func joinLines(_ s: String, delimiter: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        return lines.joined(separator: delimiter)
    }

    /// Splits each line on the given delimiter and flattens into one-item-per-line output.
    nonisolated static func splitLines(on delimiter: String, _ s: String) -> String {
        guard !delimiter.isEmpty else { return s }
        let lines = s.components(separatedBy: .newlines)
        let pieces = lines.flatMap { line in
            line.components(separatedBy: delimiter)
        }
        return pieces.joined(separator: "\n")
    }

    // MARK: - Join / Split defaults

    /// Built-in joiners/splitters for the Join / Split menus.
    /// Users can extend with `SplitJoinDelimiters` defaults (see README).
    nonisolated static func builtinMultilineJoiners() -> [(label: String, delimiter: String)] {
        [
            ("Commas", ","),
            ("Spaces", " "),
            ("CommaSpaces", ", "),
            ("Tabs", "\t"),
            ("Pipes", "|"),
            ("Colons", ":"),
            ("Semicolons", ";"),
        ]
    }

    /// Custom joiners/splitters backed by UserDefaults key `SplitJoinDelimiters`.
    /// Stored as a dictionary of menu label → delimiter.
    nonisolated static func customMultilineJoiners() -> [(label: String, delimiter: String)] {
        let key = "SplitJoinDelimiters"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }
        return dict.keys.sorted().compactMap { k in
            guard let delim = dict[k], !delim.isEmpty else { return nil }
            return (label: k, delimiter: delim)
        }
    }

    // MARK: - Remove / Swap helpers

    /// Removes all occurrences of `target` from the string.
    nonisolated static func removeSubstring(_ s: String, target: String) -> String {
        guard !target.isEmpty else { return s }
        return s.replacingOccurrences(of: target, with: "")
    }

    /// Custom removes backed by UserDefaults key `TextRemoves` (label → substring).
    nonisolated static func customMultilineRemoves() -> [(label: String, target: String)] {
        let key = "TextRemoves"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }
        return dict.keys.sorted().compactMap { k in
            guard let target = dict[k], !target.isEmpty else { return nil }
            return (label: k, target: target)
        }
    }

    /// Keeps only lines that contain `filter` as a substring.
    nonisolated static func includeLinesContaining(_ s: String, filter: String) -> String {
        guard !filter.isEmpty else { return s }
        return s.components(separatedBy: .newlines)
            .filter { $0.contains(filter) }
            .joined(separator: "\n")
    }

    /// Removes lines that contain `filter` as a substring.
    nonisolated static func excludeLinesContaining(_ s: String, filter: String) -> String {
        guard !filter.isEmpty else { return s }
        return s.components(separatedBy: .newlines)
            .filter { !$0.contains(filter) }
            .joined(separator: "\n")
    }

    /// Custom include filters backed by UserDefaults key `TextLineIncludeFilters` (label → filter string).
    nonisolated static func customMultilineIncludeFilters() -> [(label: String, filter: String)] {
        let key = "TextLineIncludeFilters"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }
        return dict.keys.sorted().compactMap { k in
            guard let filter = dict[k], !filter.isEmpty else { return nil }
            return (label: k, filter: filter)
        }
    }

    /// Custom exclude filters backed by UserDefaults key `TextLineExcludeFilters` (label → filter string).
    nonisolated static func customMultilineExcludeFilters() -> [(label: String, filter: String)] {
        let key = "TextLineExcludeFilters"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }
        return dict.keys.sorted().compactMap { k in
            guard let filter = dict[k], !filter.isEmpty else { return nil }
            return (label: k, filter: filter)
        }
    }

    /// Replaces all occurrences of `from` with `to` in the string.
    nonisolated static func swapSubstrings(_ s: String, from: String, to: String) -> String {
        guard !from.isEmpty else { return s }
        return s.replacingOccurrences(of: from, with: to)
    }

    /// Custom swaps backed by UserDefaults key `TextSwaps`.
    /// Value format: "from->to". Whitespace around arrows is ignored.
    nonisolated static func customMultilineSwaps() -> [(label: String, from: String, to: String)] {
        let key = "TextSwaps"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }

        return dict.keys.sorted().compactMap { label in
            guard let spec = dict[label] else { return nil }
            let parts = spec.split(separator: ">", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].hasSuffix("-") else { return nil }
            let fromPart = parts[0].dropLast() // strip trailing '-'
            let toPart = parts[1]
            let from = fromPart.trimmingCharacters(in: .whitespacesAndNewlines)
            let to = toPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !from.isEmpty else { return nil }
            return (label: label, from: from, to: to)
        }
    }

    /// Swaps common “fancy” quotes with straight quotes.
    nonisolated static func fancyQuotesToStraight(_ s: String) -> String {
        var out = s
        let mappings: [String: String] = [
            "“": "\"", "”": "\"",
            "„": "\"", "‟": "\"",
            "‘": "'", "’": "'",
            "‚": "'", "‛": "'",
        ]
        for (from, to) in mappings {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }

    /// Removes common zero-width characters across the entire string.
    nonisolated static func removeZeroWidthCharacters(_ s: String) -> String {
        // ZERO WIDTH SPACE, ZERO WIDTH NON-JOINER, ZERO WIDTH JOINER, ZERO WIDTH NO-BREAK SPACE (BOM)
        let zeroWidthScalars: [UnicodeScalar] = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        let zeroWidthSet = CharacterSet(zeroWidthScalars)
        return s.unicodeScalars.filter { !zeroWidthSet.contains($0) }.map(String.init).joined()
    }

    // MARK: - JSON array helpers for multiline input

    /// Converts a multiline string into a JSON array of typed literals.
    /// Lines that are wrapped in single or double quotes are always emitted as strings.
    nonisolated static func linesToTypedJsonArray(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        let values: [Any] = lines.map { rawLine in
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return NSNull() }

            if let first = trimmed.first,
               let last = trimmed.last,
               (first == "\"" && last == "\"") || (first == "'" && last == "'"),
               trimmed.count >= 2 {
                let inner = String(trimmed.dropFirst().dropLast())
                return inner
            }

            if let b = parseBooleanLiteral(trimmed) { return b }
            if let i = Int(trimmed) { return i }
            if let d = Double(trimmed), d.isFinite { return d }

            return trimmed
        }

        let cleaned = values
        guard let data = try? JSONSerialization.data(withJSONObject: cleaned, options: []),
              let out = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return out
    }

    /// Converts a multiline string into a JSON array of strings.
    nonisolated static func linesToStringJsonArray(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        guard let data = try? JSONSerialization.data(withJSONObject: lines, options: []),
              let out = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return out
    }

    /// When the input is a simple literal JSON array (validated elsewhere),
    /// returns one value per line with no quotes around string literals.
    nonisolated static func simpleLiteralJsonArrayToLines(_ s: String) -> String? {
        guard let data = s.data(using: .utf8) else { return nil }
        guard let arrayAny = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }

        let rendered: [String] = arrayAny.map { value in
            switch value {
            case let str as String:
                return str
            case let num as NSNumber:
                // NSNumber can be bool or number; detect bool first.
                if CFGetTypeID(num) == CFBooleanGetTypeID() {
                    return num.boolValue ? "true" : "false"
                }
                return String(describing: num)
            case is NSNull:
                return "null"
            default:
                return String(describing: value)
            }
        }
        return rendered.joined(separator: "\n")
    }

    /// Helper to parse boolean literals for typed JSON arrays.
    private nonisolated static func parseBooleanLiteral(_ s: String) -> Bool? {
        switch s.lowercased() {
        case "true", "t": return true
        case "false", "f": return false
        default: return nil
        }
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

    // MARK: - Awk-style column extraction

    /// Parses and executes a very small subset of awk, focused on:
    /// - Optional `-d 'X'` or `-d "X"` delimiter flag
    /// - A single `{print ...}` block
    /// - `$N` field references (1-based)
    /// - String literals in single or double quotes
    ///
    /// Spaces outside of quotes are ignored (concatenation), mirroring awk's
    /// `{print $1 $2 $3}` behavior.
    ///
    /// Examples:
    /// - `"{print $1\" my text \"$2}"` (default whitespace delimiter)
    /// - `"-d '/' {print $4\" \"$5\" \"$6}"` (slash-delimited)
    nonisolated static func awk(_ s: String, command: String) -> String {
        let (delimiter, printBody) = parseAwkCommand(command)
        let tokens = parseAwkPrintBody(printBody)
        return awkApply(s, tokens: tokens, delimiter: delimiter)
    }

    /// Simulates a basic `awk '{print $1, $3, ...}'` over multiline input.
    /// - Parameters:
    ///   - s: Source text (possibly multiline).
    ///   - columns: 1-based column indices to extract in order.
    ///   - delimiter: When empty (default), treats any run of spaces/tabs as a single delimiter and
    ///                left-trims each line before splitting. When non-empty, uses the delimiter
    ///                string as-is and preserves empty fields between consecutive delimiters.
    /// - Returns: Extracted columns, joined by single spaces per line, preserving input newlines.
    nonisolated static func awkPrintColumns(_ s: String, columns: [Int], delimiter: String = "") -> String {
        guard !columns.isEmpty else { return s }

        let lines = s.components(separatedBy: .newlines)
        var outLines: [String] = []

        // Precompute normalized column indices (1-based, positive only).
        let positiveColumns = columns.filter { $0 > 0 }
        if positiveColumns.isEmpty {
            return s
        }

        for line in lines {
            let fields = splitAwkFields(line: line, delimiter: delimiter.isEmpty ? nil : delimiter)
            if fields.isEmpty {
                outLines.append("")
                continue
            }

            var selected: [String] = []
            selected.reserveCapacity(positiveColumns.count)

            for col in positiveColumns {
                let idx = col - 1
                if idx >= 0 && idx < fields.count {
                    selected.append(fields[idx])
                } else {
                    selected.append("")
                }
            }

            // Mirror awk behavior: join requested fields with a single space.
            // If all requested columns are out-of-range, this yields an empty string.
            let joined = selected.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            outLines.append(joined)
        }

        return outLines.joined(separator: "\n")
    }

    /// Custom Awk-style print patterns backed by UserDefaults key `AwkPrintPatterns`.
    ///
    /// Dictionary shape: label → awkCommand
    /// Examples:
    /// - `"FirstAndSecond" = "{print $1\" \"$2}"`
    /// - `"SlashCols" = "-d '/' {print $4\" \"$5\" \"$6}"`
    nonisolated static func customAwkPrintPatterns() -> [(label: String, command: String)] {
        let key = "AwkPrintPatterns"
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: key) as? [String: String], !dict.isEmpty else {
            return []
        }
        return dict.keys.sorted().compactMap { label in
            guard let cmd = dict[label], !cmd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return (label: label, command: cmd)
        }
    }

    // MARK: - Private Awk helpers

    private enum AwkToken {
        case field(Int)
        case literal(String)
    }

    /// Parses the overall awk command into (delimiter?, printBody).
    private nonisolated static func parseAwkCommand(_ cmd: String) -> (delimiter: String?, printBody: String) {
        var command = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
        var delimiter: String? = nil

        // Optional -d 'x' or -d "x"
        if command.hasPrefix("-d") {
            var idx = command.index(command.startIndex, offsetBy: 2)
            // Skip whitespace
            while idx < command.endIndex, command[idx].isWhitespace {
                idx = command.index(after: idx)
            }
            if idx < command.endIndex, command[idx] == "'" || command[idx] == "\"" {
                let quote = command[idx]
                idx = command.index(after: idx)
                var delimScalars: [Character] = []
                while idx < command.endIndex, command[idx] != quote {
                    delimScalars.append(command[idx])
                    idx = command.index(after: idx)
                }
                if idx < command.endIndex && command[idx] == quote {
                    idx = command.index(after: idx)
                    delimiter = String(delimScalars)
                    command = String(command[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Find `{print` outside of quotes and then matching closing `}`.
        let (body, _) = extractPrintBody(command)
        return (delimiter, body)
    }

    /// Extracts the contents of the first `{print ...}` block, ignoring braces in quotes.
    private nonisolated static func extractPrintBody(_ s: String) -> (body: String, range: Range<String.Index>?) {
        var inQuotes = false
        var quoteChar: Character = "\0"
        var depth = 0
        var printStart: String.Index? = nil
        var bodyStart: String.Index? = nil

        var idx = s.startIndex
        while idx < s.endIndex {
            let ch = s[idx]

            if inQuotes {
                if ch == quoteChar {
                    inQuotes = false
                }
                idx = s.index(after: idx)
                continue
            }

            if ch == "'" || ch == "\"" {
                inQuotes = true
                quoteChar = ch
                idx = s.index(after: idx)
                continue
            }

            if ch == "{" {
                depth += 1
                // Look for "print" immediately after this brace (ignoring spaces).
                var look = s.index(after: idx)
                while look < s.endIndex, s[look].isWhitespace {
                    look = s.index(after: look)
                }
                if look < s.endIndex, s[look...].hasPrefix("print") {
                    printStart = idx
                    bodyStart = s.index(look, offsetBy: "print".count)
                }
            } else if ch == "}" {
                if depth > 0 {
                    depth -= 1
                    if depth == 0, let pStart = printStart, let bStart = bodyStart {
                        let range: Range<String.Index> = pStart..<s.index(after: idx)
                        let body = s[bStart..<idx]
                        return (String(body).trimmingCharacters(in: .whitespacesAndNewlines), range)
                    }
                }
            }

            idx = s.index(after: idx)
        }

        return (s, nil)
    }

    /// Parses the body of a `print` statement into tokens.
    private nonisolated static func parseAwkPrintBody(_ body: String) -> [AwkToken] {
        var tokens: [AwkToken] = []
        var idx = body.startIndex
        var inQuotes = false
        var quoteChar: Character = "\0"
        var currentLiteral = ""

        func flushLiteral() {
            if !currentLiteral.isEmpty {
                tokens.append(.literal(currentLiteral))
                currentLiteral = ""
            }
        }

        while idx < body.endIndex {
            let ch = body[idx]

            if inQuotes {
                if ch == quoteChar {
                    // End quote
                    flushLiteral()
                    inQuotes = false
                } else {
                    currentLiteral.append(ch)
                }
                idx = body.index(after: idx)
                continue
            }

            if ch == "'" || ch == "\"" {
                inQuotes = true
                quoteChar = ch
                idx = body.index(after: idx)
                continue
            }

            if ch == "$" {
                // Field reference
                idx = body.index(after: idx)
                var numStr = ""
                while idx < body.endIndex, let scalar = body[idx].unicodeScalars.first, CharacterSet.decimalDigits.contains(scalar) {
                    numStr.append(body[idx])
                    idx = body.index(after: idx)
                }
                if let n = Int(numStr), n > 0 {
                    flushLiteral()
                    tokens.append(.field(n))
                }
                continue
            }

            // Outside quotes: spaces are ignored; other chars are ignored (we don't support variables).
            idx = body.index(after: idx)
        }

        flushLiteral()
        return tokens
    }

    /// Splits a single line into fields using either whitespace (nil delimiter) or an explicit delimiter string.
    private nonisolated static func splitAwkFields(line: String, delimiter: String?) -> [String] {
        if let delimiter = delimiter, !delimiter.isEmpty {
            if line.isEmpty { return [] }
            return line.components(separatedBy: delimiter)
        } else {
            // Whitespace mode: trim leading spaces/tabs, then split on runs of spaces/tabs.
            let trimmedLeft = line.replacingOccurrences(of: "^[ \\t]+", with: "", options: .regularExpression)
            if trimmedLeft.isEmpty { return [] }
            let pattern = "[ \\t]+"
            return trimmedLeft
                .replacingOccurrences(of: pattern, with: "\u{0001}", options: .regularExpression)
                .components(separatedBy: "\u{0001}")
        }
    }

    /// Applies parsed awk tokens to each line of the input.
    private nonisolated static func awkApply(_ s: String, tokens: [AwkToken], delimiter: String?) -> String {
        guard !tokens.isEmpty else { return s }
        let lines = s.components(separatedBy: .newlines)
        var out: [String] = []
        out.reserveCapacity(lines.count)

        for line in lines {
            let fields = splitAwkFields(line: line, delimiter: delimiter)
            var buf = ""
            for token in tokens {
                switch token {
                case .literal(let lit):
                    buf.append(lit)
                case .field(let idx1):
                    let idx0 = idx1 - 1
                    if idx0 >= 0 && idx0 < fields.count {
                        buf.append(fields[idx0])
                    }
                }
            }
            out.append(buf)
        }

        return out.joined(separator: "\n")
    }
}
