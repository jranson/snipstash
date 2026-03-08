import AppKit
import CryptoKit
import Foundation

// MARK: - Feedback sounds

@MainActor
enum ClipboardSound {
    static func playClipboardWritten(muted: Bool) {
        guard !muted, let snd = NSSound(named: "Frog") else { return }
        snd.volume = 0.25
        snd.play()
    }

    static func playClipboardError(muted: Bool) {
        guard !muted else { return }
        NSSound.beep()
    }
}

// MARK: - Clipboard read/write

@MainActor
enum ClipboardIO {
    static func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    @discardableResult
    static func writeString(_ string: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - Transform clipboard (read → transform → write)

@MainActor
enum ClipboardTransform {
    /// Read clipboard, apply transform, write back. Plays success or error sound.
    @discardableResult
    static func apply(_ transform: (String) -> String, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        let result = transform(str)
        guard ClipboardIO.writeString(result) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        ClipboardSound.playClipboardWritten(muted: muted)
        return true
    }

    /// Like apply, but transform returns nil on failure (e.g. invalid URL). On nil, beeps and does not write.
    @discardableResult
    static func applyIfValid(_ transform: (String) -> String?, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        guard let result = transform(str) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        guard ClipboardIO.writeString(result) else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        ClipboardSound.playClipboardWritten(muted: muted)
        return true
    }

    // MARK: - Case / whitespace

    static func lowercase(_ s: String) -> String { s.lowercased() }
    static func uppercase(_ s: String) -> String { s.uppercased() }
    static func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func lowercaseTrimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    /// Lowercase, trim, replace spaces with hyphens, strip non-alphanumeric (except - and _). Good for URL slugs.
    static func slugify(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let withHyphens = trimmed.replacingOccurrences(of: " ", with: "-")
        return withHyphens.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // MARK: - URL

    /// Remove query string and fragment from URL(s) in the text. Handy for stripping tracking from retail links.
    static func stripUrlParams(_ s: String) -> String {
        s.components(separatedBy: .newlines).map { line in
            line.split(separator: " ").map { word -> String in
                var str = String(word)
                if let q = str.firstIndex(of: "?") { str = String(str[..<q]) }
                if let h = str.firstIndex(of: "#") { str = String(str[..<h]) }
                return str
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    /// stripUrlParams that returns nil when the content doesn't contain a parseable URL or result would be empty (so caller can beep instead of writing).
    static func stripUrlParamsIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        let firstWord = firstLine.split(separator: " ").first.map(String.init) ?? firstLine
        guard URL(string: String(firstWord)) != nil else { return nil }
        let result = stripUrlParams(s)
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return result
    }

    static func urlEncode(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func urlDecode(_ s: String) -> String {
        s.removingPercentEncoding ?? s
    }

    /// Parse clipboard as URL and extract the host. Returns nil if not parseable or host would be empty.
    static func urlExtractHostIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        return host
    }

    /// Parse clipboard as URL and extract the path (pathname). Returns nil if not parseable or path would be empty.
    static func urlExtractPathIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), !url.path.isEmpty else { return nil }
        return url.path
    }

    /// Parse clipboard as URL and extract the fragment (hash). Returns nil if not parseable or fragment would be empty.
    static func urlExtractFragmentIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let fragment = url.fragment, !fragment.isEmpty else { return nil }
        return fragment
    }

    /// Parse clipboard as URL and extract the query string (params). Returns nil if not parseable or query would be empty.
    static func urlExtractQueryIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let query = url.query, !query.isEmpty else { return nil }
        return query
    }

    // MARK: - Base64

    static func base64Encode(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    static func base64Decode(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return s }
        return decoded
    }

    // MARK: - Checksums

    static func md5Checksum(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    static func sha1Checksum(_ s: String) -> String {
        Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    static func sha256Checksum(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    // MARK: - JSON

    static func jsonPrettify(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: pretty, encoding: .utf8) else { return s }
        return out
    }

    static func jsonMinify(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: json),
              let out = String(data: compact, encoding: .utf8) else { return s }
        return out
    }

    // MARK: - Quote escaping

    static func escapeDoubleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func unescapeDoubleQuotes(_ s: String) -> String {
        // Handle \\ before \" so escaped backslashes round-trip correctly
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    static func escapeSingleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    static func unescapeSingleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    static func escapeBackslashes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
    }

    static func unescapeBackslashes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\\")
    }

    static func escapeDollar(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    static func unescapeDollar(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\\", with: "\u{0}")
            .replacingOccurrences(of: "\\$", with: "$")
            .replacingOccurrences(of: "\u{0}", with: "\\")
    }

    // MARK: - CSV / TSV

    /// Convert CSV to TSV for pasting into spreadsheet apps (handles quoted fields).
    static func csvToTsv(_ s: String) -> String {
        func parseCSVLine(_ line: String) -> [String] {
            var fields: [String] = []
            var current = ""
            var inQuotes = false
            for c in line.unicodeScalars {
                switch c {
                case "\"": inQuotes.toggle()
                case "," where !inQuotes:
                    fields.append(current)
                    current = ""
                default:
                    current.append(Character(c))
                }
            }
            fields.append(current)
            return fields
        }
        return s.components(separatedBy: .newlines)
            .map { parseCSVLine($0).joined(separator: "\t") }
            .joined(separator: "\n")
    }

    // MARK: - Line tools

    /// Convert Windows line endings (\r\n) to Unix (\n). Also normalizes standalone \r.
    static func windowsNewlinesToUnix(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func sortLines(_ s: String) -> String {
        s.components(separatedBy: .newlines).sorted().joined(separator: "\n")
    }

    static func deduplicateLines(_ s: String) -> String {
        var seen = Set<String>()
        return s.components(separatedBy: .newlines)
            .filter { seen.insert($0).inserted }
            .joined(separator: "\n")
    }

    static func sortAndDeduplicateLines(_ s: String) -> String {
        var seen = Set<String>()
        return s.components(separatedBy: .newlines)
            .sorted()
            .filter { seen.insert($0).inserted }
            .joined(separator: "\n")
    }

    static func reverseLines(_ s: String) -> String {
        s.components(separatedBy: .newlines).reversed().joined(separator: "\n")
    }
}

// MARK: - Set clipboard to generated values (dates, UUID)

@MainActor
enum ClipboardSet {
    static func setAndNotify(_ value: String, muted: Bool) {
        guard ClipboardIO.writeString(value) else { return }
        ClipboardSound.playClipboardWritten(muted: muted)
    }

    private static let sqlLocalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private static let sqlUTCFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let rfc3339ZFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let rfc3339OffsetFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func epochSeconds() -> String { String(Int(Date().timeIntervalSince1970)) }
    static func epochMilliseconds() -> String { String(Int64(Date().timeIntervalSince1970 * 1000)) }
    static func sqlDateTimeLocal() -> String { sqlLocalFormatter.string(from: Date()) }
    static func sqlDateTimeUTC() -> String { sqlUTCFormatter.string(from: Date()) }

    static func rfc3339Z() -> String { rfc3339ZFormatter.string(from: Date()) }

    static func rfc3339WithOffset() -> String { rfc3339OffsetFormatter.string(from: Date()) }

    static func rfc3339WithAbbreviation() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSzzz"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }

    static func randomUUID() -> String { UUID().uuidString }
    static func randomUUIDLowercase() -> String { UUID().uuidString.lowercased() }
}
