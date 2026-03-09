import AppKit
import CryptoKit
import Darwin
import Foundation
import Security

// MARK: - Argon2 parameters (UserDefaults-backed)

enum Argon2Params {
    /// Clamps memoryKiB, iterations, parallelism to valid RFC 9106 ranges. Defaults to 65535, 3, 1 when invalid.
    nonisolated static func sanitized(memoryKiB: Int, iterations: Int, parallelism: Int) -> (memoryKiB: Int, iterations: Int, parallelism: Int) {
        let p = max(1, parallelism)
        let t = max(1, iterations)
        let minM = max(8, 8 * p)
        let m = memoryKiB >= minM ? memoryKiB : 65535
        return (m, t, p)
    }
}

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
    struct TransformError: LocalizedError, CustomStringConvertible {
        let description: String
        var errorDescription: String? { description }
    }

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

    /// Like applyIfValid, but captures typed transform errors so DEBUG builds can log the exact reason.
    @discardableResult
    static func applyIfValid(_ transform: (String) throws -> String, muted: Bool) -> Bool {
        guard let str = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
        do {
            let result = try transform(str)
            guard ClipboardIO.writeString(result) else {
                ClipboardSound.playClipboardError(muted: muted)
                return false
            }
            ClipboardSound.playClipboardWritten(muted: muted)
            return true
        } catch {
            #if DEBUG
            print("[ClipboardTransform] \(error)")
            #endif
            ClipboardSound.playClipboardError(muted: muted)
            return false
        }
    }

    // MARK: - Case / whitespace (nonisolated so tests can call without main actor)

    nonisolated static func lowercase(_ s: String) -> String { s.lowercased() }
    nonisolated static func uppercase(_ s: String) -> String { s.uppercased() }
    nonisolated static func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    nonisolated static func lowercaseTrimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    /// Lowercase, trim, replace spaces with hyphens, strip non-alphanumeric (except - and _). Good for URL slugs.
    nonisolated static func slugify(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let withHyphens = trimmed.replacingOccurrences(of: " ", with: "-")
        return withHyphens.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
            .map(String.init)
            .joined()
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Title Case: first letter of each word uppercase, rest lowercase.
    nonisolated static func titleCase(_ s: String) -> String {
        s.lowercased().capitalized
    }

    /// Sentence case: first character uppercase, rest lowercase.
    nonisolated static func sentenceCase(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return s }
        return t.prefix(1).uppercased() + t.dropFirst().lowercased()
    }

    /// camelCase: first word lowercase, subsequent words capitalized, no spaces.
    nonisolated static func camelCase(_ s: String) -> String {
        let words = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return s }
        let first = words[0].lowercased()
        let rest = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return first + rest.joined()
    }

    /// PascalCase: each word capitalized, no spaces.
    nonisolated static func pascalCase(_ s: String) -> String {
        let words = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }

    /// snake_case: words joined with underscores, lowercase.
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

    /// CONST_CASE: snake_case + UPPERCASE (e.g. MY_CONSTANT_NAME).
    nonisolated static func constCase(_ s: String) -> String {
        snakeCase(s).uppercased()
    }

    // MARK: - URL

    /// Remove query string and fragment from URL(s) in the text. Handy for stripping tracking from retail links.
    nonisolated static func stripUrlParams(_ s: String) -> String {
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
    nonisolated static func stripUrlParamsIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        let firstWord = firstLine.split(separator: " ").first.map(String.init) ?? firstLine
        guard URL(string: String(firstWord)) != nil else { return nil }
        let result = stripUrlParams(s)
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return result
    }

    nonisolated static func urlEncode(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    nonisolated static func urlDecode(_ s: String) -> String {
        s.removingPercentEncoding ?? s
    }

    /// Parse clipboard as URL and extract the host (no port). Returns nil if not parseable or host would be empty.
    nonisolated static func urlExtractHostIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        return host
    }

    /// Parse clipboard as URL and extract host with optional port, e.g. "google.com:8443" or "google.com". Returns nil if not parseable or host would be empty.
    nonisolated static func urlExtractHostPortIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }

    /// Parse clipboard as URL and extract the port number. Returns nil if not parseable or URL has no port (caller can beep).
    nonisolated static func urlExtractPortIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let port = url.port else { return nil }
        return String(port)
    }

    /// Parse clipboard as URL and extract the path (pathname). Returns nil if not parseable or path would be empty.
    nonisolated static func urlExtractPathIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), !url.path.isEmpty else { return nil }
        return url.path
    }

    /// Parse clipboard as URL and extract the fragment (hash). Returns nil if not parseable or fragment would be empty.
    nonisolated static func urlExtractFragmentIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let fragment = url.fragment, !fragment.isEmpty else { return nil }
        return fragment
    }

    /// Parse clipboard as URL and extract the query string (params). Returns nil if not parseable or query would be empty.
    nonisolated static func urlExtractQueryIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let query = url.query, !query.isEmpty else { return nil }
        return query
    }

    // MARK: - Base64

    nonisolated static func base64Encode(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    nonisolated static func base64Decode(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return s }
        return decoded
    }

    // MARK: - Checksums

    nonisolated static func md5Checksum(_ s: String) -> String {
        Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha1Checksum(_ s: String) -> String {
        Insecure.SHA1.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha256Checksum(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    nonisolated static func sha512Checksum(_ s: String) -> String {
        SHA512.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }

    /// Sanitizes Argon2id parameters from UserDefaults so they satisfy RFC 9106 (e.g. m ≥ 8p, t ≥ 1, p ≥ 1).
    private nonisolated static func argon2ParamsFromUserDefaults() -> (memoryKiB: Int, iterations: Int, parallelism: Int) {
        let ud = UserDefaults.standard
        let m = ud.integer(forKey: "Argon2MemoryKiB")
        let t = ud.integer(forKey: "Argon2Iterations")
        let p = ud.integer(forKey: "Argon2Parallelism")
        return Argon2Params.sanitized(memoryKiB: m, iterations: t, parallelism: p)
    }

    /// Argon2id hash (RFC 9106). Uses random 16-byte salt; returns PHC string or nil.
    /// Parameters come from UserDefaults (see SnipStashApp); override with:
    ///   defaults write org.centennialoss.snipstash Argon2MemoryKiB &lt;KiB&gt;
    ///   defaults write org.centennialoss.snipstash Argon2Iterations &lt;t&gt;
    ///   defaults write org.centennialoss.snipstash Argon2Parallelism &lt;p&gt;
    nonisolated static func argon2idHash(_ s: String) -> String? {
        let password = Data(s.utf8)
        let (m, t, p) = argon2ParamsFromUserDefaults()
        return Argon2PHC.hash(password: password, memoryKiB: m, iterations: t, parallelism: p, tagLength: 32)
    }

    /// bcrypt hash using system crypt(3) with autogenerated $2b$ salt.
    /// Returns nil if hashing fails.
    nonisolated static func bcryptHash(_ s: String) -> String? {
        let cost = 12
        let salt = "$2b$\(String(format: "%02d", cost))$\(bcryptRandomSaltBody(length: 22))"
        guard let out = crypt(s, salt) else { return nil }
        return String(cString: out)
    }

    private nonisolated static func bcryptRandomSaltBody(length: Int) -> String {
        let alphabet = Array("./ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return (0..<length).map { _ in
            let idx = Int(arc4random_uniform(UInt32(alphabet.count)))
            return String(alphabet[idx])
        }.joined()
    }

    // MARK: - Base64URL (uses - and _ instead of + and /)

    nonisolated static func base64URLEncode(_ s: String) -> String {
        base64URLEncodeData(Data(s.utf8))
    }

    private nonisolated static func base64URLEncodeData(_ data: Data) -> String {
        let base64 = data.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    nonisolated static func base64URLDecode(_ s: String) -> String {
        var base64 = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad == 2 { base64 += "==" } else if pad == 3 { base64 += "=" }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let decoded = String(data: data, encoding: .utf8) else { return s }
        return decoded
    }

    // MARK: - CRC32 (CRC-32B / polynomial 0x04C11DB7)

    nonisolated static func crc32(_ s: String) -> String {
        String(format: "%08x", CRC32B.hash(Data(s.utf8)))
    }

    // MARK: - JWT (encode/decode payload only; no signature verification)

    /// Build a JWT from clipboard JSON as payload; default header and HMAC-SHA256 signature over header.payload.
    nonisolated static func jwtEncode(_ s: String) -> String? {
        let header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
        let payload = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }
        let h = base64URLEncode(header)
        let p = base64URLEncode(payload)
        let unsigned = h + "." + p
        let digest = SHA256.hash(data: Data(unsigned.utf8))
        let sig = base64URLEncodeData(Data(digest))
        return unsigned + "." + sig
    }

    /// Decode JWT and return payload as pretty-printed JSON (does not verify signature).
    nonisolated static func jwtDecode(_ s: String) -> String? {
        let parts = s.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])
        let decoded = base64URLDecode(payloadPart)
        guard let data = decoded.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: pretty, encoding: .utf8) else { return decoded }
        return out
    }

    // MARK: - JSON

    nonisolated static func jsonPrettify(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: pretty, encoding: .utf8) else { return s }
        return out
    }

    nonisolated static func jsonMinify(_ s: String) -> String {
        guard let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: json),
              let out = String(data: compact, encoding: .utf8) else { return s }
        return out
    }

    /// Sort JSON keys alphabetically. Minifies if trimmed input has no newlines; prettifies otherwise.
    nonisolated static func jsonSortKeys(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return s }
        let newlineCount = trimmed.components(separatedBy: "\n").count - 1
        if newlineCount == 0 {
            guard let compact = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
                  let out = String(data: compact, encoding: .utf8) else { return s }
            return out
        } else {
            guard let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                  let out = String(data: pretty, encoding: .utf8) else { return s }
            return out
        }
    }

    // MARK: - YAML (pure Swift; handles JSON-compatible YAML and simple indented key: value)

    /// Prettify YAML with consistent 2-space indentation. If input is valid JSON, uses JSON prettify.
    /// If input is minified YAML (e.g. {key: value, ...}), parses and emits pretty indented YAML.
    nonisolated static func yamlPrettify(_ s: String) -> String {
        if let data = s.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return jsonPrettify(s)
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}"), let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) as? [String: Any] {
            return YAMLHelpers.emitYAML(parsed, indent: 0)
        }
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) as? [Any] {
            return YAMLHelpers.emitYAML(parsed, indent: 0)
        }
        return YAMLHelpers.prettify(s)
    }

    /// Minify YAML to a single line where safe. If input is valid JSON, uses JSON minify.
    nonisolated static func yamlMinify(_ s: String) -> String {
        if let data = s.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return jsonMinify(s)
        }
        return YAMLHelpers.minify(s)
    }

    /// Convert JSON string to YAML-style output (indented key: value, list items with -).
    nonisolated static func jsonToYaml(_ s: String) throws -> String {
        guard let data = s.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            throw TransformError(description: "JSON → YAML failed: clipboard does not contain valid JSON.")
        }
        return YAMLHelpers.emitYAML(json, indent: 0)
    }

    /// Convert YAML string to JSON. Minified YAML input → minified JSON; multi-line YAML → prettified JSON.
    nonisolated static func yamlToJson(_ s: String) throws -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMinifiedInput = ((trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))) && !trimmed.contains("\n")

        let obj: Any?
        if isMinifiedInput, let parsed = YAMLHelpers.parseMinifiedYAML(trimmed) {
            obj = parsed
        } else {
            obj = YAMLHelpers.parseYAML(s)
        }
        guard let obj = obj else {
            throw TransformError(description: "YAML → JSON failed: clipboard does not contain parseable YAML.")
        }
        let jsonObj = YAMLHelpers.anyToJSONCompatible(obj)
        let options: JSONSerialization.WritingOptions = isMinifiedInput ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObj, options: options),
              let out = String(data: data, encoding: .utf8) else {
            throw TransformError(description: "YAML → JSON failed: parsed YAML could not be encoded as JSON.")
        }
        return out
    }

    // MARK: - CSV ↔ JSON

    /// Parse CSV (first line = headers) and return JSON array of objects.
    nonisolated static func csvToJson(_ s: String) throws -> String {
        let rows = parseCSVRows(s)
        guard let first = rows.first, !first.isEmpty else {
            throw TransformError(description: "CSV → JSON failed: no CSV header row was found.")
        }
        let headers = first
        let objects: [[String: String]] = rows.dropFirst().map { values in
            var dict: [String: String] = [:]
            for (i, key) in headers.enumerated() {
                dict[key] = i < values.count ? values[i] : ""
            }
            return dict
        }
        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted]),
              let out = String(data: data, encoding: .utf8) else {
            throw TransformError(description: "CSV → JSON failed: CSV rows could not be encoded as JSON.")
        }
        return out
    }

    /// Parse JSON array of objects and output CSV with headers from first object keys.
    nonisolated static func jsonArrayToCsv(_ s: String) throws -> String {
        guard let data = s.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !array.isEmpty else {
            throw TransformError(description: "JSON Array → CSV failed: clipboard must contain a non-empty JSON array of objects.")
        }
        let keys: [String] = (array.first?.keys.map { $0 } ?? []).sorted()
        guard !keys.isEmpty else {
            throw TransformError(description: "JSON Array → CSV failed: the first object does not contain any keys.")
        }
        func escape(_ v: String) -> String {
            if v.contains(",") || v.contains("\"") || v.contains("\n") {
                return "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return v
        }
        let headerLine = keys.map(escape).joined(separator: ",")
        let dataLines = array.map { obj in
            keys.map { escape(String(describing: obj[$0] ?? "")) }.joined(separator: ",")
        }
        return ([headerLine] + dataLines).joined(separator: "\n")
    }

    nonisolated static func csvToPsv(_ s: String) -> String {
        parseCSVRows(s).map { makeDelimitedLine($0, delimiter: "|") }.joined(separator: "\n")
    }

    nonisolated static func psvToCsv(_ s: String) throws -> String {
        try delimitedToCsv(s, delimiter: "|", formatName: "PSV")
    }

    nonisolated static func tsvToCsv(_ s: String) throws -> String {
        try delimitedToCsv(s, delimiter: "\t", formatName: "TSV")
    }

    /// Convert MySQL CLI table output to CSV. Ignores any text before the first table border
    /// and after the last table border.
    nonisolated static func mysqlCliTableToCsv(_ s: String) throws -> String {
        let lines = windowsNewlinesToUnix(s).components(separatedBy: .newlines)
        let borderIndices = lines.indices.filter { isMySQLCliTableBorder(lines[$0]) }
        guard let firstBorder = borderIndices.first,
              let lastBorder = borderIndices.last,
              firstBorder < lastBorder else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: could not find a complete +--- table border block.")
        }

        let tableLines = lines[firstBorder...lastBorder]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard tableLines.allSatisfy({ isMySQLCliTableBorder($0) || isMySQLCliTableRow($0) }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: found non-table text inside the detected table block.")
        }

        let rows = tableLines
            .filter(isMySQLCliTableRow)
            .map(parseMySQLCliTableRow)

        guard let headers = rows.first, !headers.isEmpty, rows.count >= 2 else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: expected a header row plus at least one data row.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "MySQL CLI Table → CSV failed: one or more rows have a different number of columns than the header.")
        }

        func escapeCSV(_ value: String) -> String {
            if value.contains(",") || value.contains("\"") || value.contains("\n") {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }

        return rows.map { row in
            row.map(escapeCSV).joined(separator: ",")
        }.joined(separator: "\n")
    }

    /// Convert psql CLI table output to CSV. Expects trimmed table-only text with a header line,
    /// a dashed separator line, and one or more data rows.
    nonisolated static func psqlCliTableToCsv(_ s: String) throws -> String {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let separatorIndex = lines.firstIndex(where: isPsqlCliTableSeparator),
              separatorIndex > 0 else {
            throw TransformError(description: "psql Table → CSV failed: could not find the dashed separator line under the header.")
        }

        let headerLine = lines[separatorIndex - 1]
        let dataLines = lines[(separatorIndex + 1)...]
            .filter { !isPsqlCliTableFooter($0) }
        guard !dataLines.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: found the header, but no data rows below it.")
        }

        let headers = parsePsqlCliTableRow(headerLine)
        guard !headers.isEmpty else {
            throw TransformError(description: "psql Table → CSV failed: header row did not contain any columns.")
        }

        let parsedDataRows = dataLines.map { line in
            normalizePsqlCliTableRow(parsePsqlCliTableRow(line), headerCount: headers.count)
        }
        guard parsedDataRows.allSatisfy({ !$0.isEmpty && $0.count == headers.count }) else {
            throw TransformError(description: "psql Table → CSV failed: one or more rows could not be aligned to the header column count.")
        }

        func escapeCSV(_ value: String) -> String {
            if value.contains(",") || value.contains("\"") || value.contains("\n") {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }

        return ([headers] + parsedDataRows).map { row in
            row.map(escapeCSV).joined(separator: ",")
        }.joined(separator: "\n")
    }

    /// Convert sqlite3 column-mode table output to CSV. Columns are inferred from the dashed
    /// separator row and extracted using fixed-width boundaries.
    nonisolated static func sqlite3TableToCsv(_ s: String) throws -> String {
        let lines = windowsNewlinesToUnix(s)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard lines.count >= 3 else {
            throw TransformError(description: "sqlite3 Table → CSV failed: expected a header row, a dashed separator row, and at least one data row.")
        }
        let headerLine = lines[0]
        let separatorLine = lines[1]
        let dataLines = Array(lines.dropFirst(2))

        let columnStarts = sqlite3ColumnStarts(from: separatorLine)
        guard !columnStarts.isEmpty else {
            throw TransformError(description: "sqlite3 Table → CSV failed: could not infer fixed-width columns from the dashed separator row.")
        }

        let headers = parseSQLite3FixedWidthRow(headerLine, columnStarts: columnStarts)
        guard !headers.isEmpty, headers.contains(where: { !$0.isEmpty }) else {
            throw TransformError(description: "sqlite3 Table → CSV failed: header row did not contain any columns.")
        }

        let rows = [headers] + dataLines.map { parseSQLite3FixedWidthRow($0, columnStarts: columnStarts) }
        return rows.map { row in
            row.map(escapeCSVField).joined(separator: ",")
        }.joined(separator: "\n")
    }

    // MARK: - Quote escaping

    nonisolated static func escapeDoubleQuotes(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    nonisolated static func unescapeDoubleQuotes(_ s: String) -> String {
        // Handle \\ before \" so escaped backslashes round-trip correctly
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

    // MARK: - CSV / TSV

    /// Parse CSV into rows of fields (handles quoted fields).
    nonisolated static func parseCSVRows(_ s: String) -> [[String]] {
        parseDelimitedRows(s, delimiter: ",")
    }

    private nonisolated static func isMySQLCliTableBorder(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("+"), trimmed.hasSuffix("+") else { return false }
        let body = trimmed.dropFirst().dropLast()
        guard !body.isEmpty else { return false }
        return body.contains("+") && body.allSatisfy { $0 == "+" || $0 == "-" }
    }

    private nonisolated static func isMySQLCliTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
    }

    private nonisolated static func parseMySQLCliTableRow(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return [] }
        return parts.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func isPsqlCliTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "+", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0 == "-" }
        }
    }

    private nonisolated static func isPsqlCliTableFooter(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("("), trimmed.hasSuffix(")") else { return false }
        let body = trimmed.dropFirst().dropLast()
        return body.range(of: #"^\d+\s+rows?$"#, options: .regularExpression) != nil
    }

    private nonisolated static func parsePsqlCliTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func normalizePsqlCliTableRow(_ row: [String], headerCount: Int) -> [String] {
        guard !row.isEmpty, row.count <= headerCount else { return [] }
        if row.count == headerCount { return row }
        return row + Array(repeating: "", count: headerCount - row.count)
    }

    private nonisolated static func parseDelimitedRows(_ s: String, delimiter: Character) -> [[String]] {
        windowsNewlinesToUnix(s).components(separatedBy: .newlines).map { parseDelimitedLine($0, delimiter: delimiter) }
    }

    private nonisolated static func parseDelimitedLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == delimiter, !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i += 1
        }

        fields.append(current)
        return fields
    }

    private nonisolated static func makeDelimitedLine(_ fields: [String], delimiter: Character) -> String {
        fields.map { field in
            if field.contains(delimiter) || field.contains("\"") || field.contains("\n") {
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return field
        }.joined(separator: String(delimiter))
    }

    private nonisolated static func delimitedToCsv(_ s: String, delimiter: Character, formatName: String) throws -> String {
        let trimmed = windowsNewlinesToUnix(s).trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else {
            throw TransformError(description: "\(formatName) → CSV failed: clipboard is empty.")
        }

        let rows = parseDelimitedRows(trimmed, delimiter: delimiter)
        guard let headers = rows.first, !headers.isEmpty else {
            throw TransformError(description: "\(formatName) → CSV failed: no header row was found.")
        }
        guard rows.allSatisfy({ $0.count == headers.count }) else {
            throw TransformError(description: "\(formatName) → CSV failed: one or more rows have a different number of columns than the header.")
        }

        return rows.map { makeDelimitedLine($0, delimiter: ",") }.joined(separator: "\n")
    }

    private nonisolated static func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private nonisolated static func sqlite3ColumnStarts(from separatorLine: String) -> [Int] {
        let chars = Array(separatorLine)
        var starts: [Int] = []
        var i = 0
        while i < chars.count {
            if chars[i] == "-" {
                starts.append(i)
                while i < chars.count, chars[i] == "-" {
                    i += 1
                }
            } else if chars[i] == " " {
                i += 1
            } else {
                return []
            }
        }
        return starts
    }

    private nonisolated static func parseSQLite3FixedWidthRow(_ line: String, columnStarts: [Int]) -> [String] {
        let chars = Array(line)
        return columnStarts.enumerated().map { index, start in
            let end = index + 1 < columnStarts.count ? columnStarts[index + 1] : chars.count
            guard start < chars.count else { return "" }
            let upperBound = min(end, chars.count)
            return String(chars[start..<upperBound]).trimmingCharacters(in: .whitespaces)
        }
    }

    nonisolated static func parseCSVLine(_ line: String) -> [String] {
        parseDelimitedLine(line, delimiter: ",")
    }

    /// Convert CSV to TSV for pasting into spreadsheet apps (handles quoted fields).
    nonisolated static func csvToTsv(_ s: String) -> String {
        parseCSVRows(s).map { makeDelimitedLine($0, delimiter: "\t") }.joined(separator: "\n")
    }

    // MARK: - Line tools

    /// Convert Windows line endings (\r\n) to Unix (\n). Also normalizes standalone \r.
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

    /// Shuffle lines randomly.
    nonisolated static func shuffleLines(_ s: String) -> String {
        var lines = s.components(separatedBy: .newlines)
        lines.shuffle()
        return lines.joined(separator: "\n")
    }

    /// Remove empty/blank lines (lines containing only whitespace are treated as blank).
    nonisolated static func removeEmptyLines(_ s: String) -> String {
        s.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: "\n")
    }

    /// Add one tab character of indentation to the front of every line.
    nonisolated static func indentLines(_ s: String) -> String {
        s.components(separatedBy: "\n").map { "\t" + $0 }.joined(separator: "\n")
    }

    /// Remove one leading tab character from each line (no-op if the line has none).
    nonisolated static func unindentLines(_ s: String) -> String {
        s.components(separatedBy: "\n").map { line in
            line.hasPrefix("\t") ? String(line.dropFirst()) : line
        }.joined(separator: "\n")
    }

    /// Trim leading and trailing whitespace on each line individually.
    nonisolated static func trimLines(_ s: String) -> String {
        s.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }

    // MARK: - HTML escaping

    /// Escape HTML special characters: & < > " '
    nonisolated static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Unescape HTML entities back to their original characters.
    nonisolated static func htmlUnescape(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")  // must be last to avoid double-unescaping
    }
}

// MARK: - CRC32B (standard CRC-32, polynomial 0x04C11DB7)

enum CRC32B {
    private nonisolated static let table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = (c & 1) == 1 ? (c >> 1) ^ 0xEDB88320 : (c >> 1)
        }
        return c
    }

    nonisolated static func hash(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

// MARK: - YAML quoted string (preserves "was quoted" so e.g. '1.7' stays a string, not a number)

enum YAMLQuoteStyle {
    case single
    case double
}

struct YAMLQuotedString {
    let value: String
    let style: YAMLQuoteStyle
}

// MARK: - YAML helpers (minimal; JSON-compatible and simple key: value / - item)

enum YAMLHelpers {
    nonisolated static func prettify(_ s: String) -> String {
        let lines = s.components(separatedBy: .newlines)
        var result: [String] = []
        var indentStack: [Int] = [0]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { result.append(""); continue }
            let lead = line.prefix(while: { $0 == " " }).count
            while indentStack.count > 1 && lead < indentStack.last! {
                _ = indentStack.popLast()
            }
            if lead > indentStack.last! {
                indentStack.append(lead)
            }
            let indent = indentStack.last!
            result.append(String(repeating: " ", count: indent) + trimmed)
        }
        return result.joined(separator: "\n")
    }

    nonisolated static func minify(_ s: String) -> String {
        if let parsed = parseYAML(s) {
            return emitYAMLMinified(parsed)
        }
        let lines = s.components(separatedBy: .newlines)
        let nonComment = lines.map { line in
            if let hashIdx = line.firstIndex(of: "#") {
                return String(line[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
            return line.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        return nonComment.joined(separator: " ")
    }

    /// Emit a single-line minified representation: {key: value, ...}, [a, b, c], or scalar.
    private nonisolated static func emitYAMLMinified(_ value: Any) -> String {
        switch value {
        case let dict as [String: Any]:
            let parts = dict.sorted(by: { $0.key < $1.key }).map { k, v in
                k + ": " + emitYAMLMinified(v)
            }
            return "{" + parts.joined(separator: ", ") + "}"
        case let arr as [Any]:
            let parts = arr.map { emitYAMLMinified($0) }
            return "[" + parts.joined(separator: ", ") + "]"
        default:
            return emitYAMLScalar(value)
        }
    }

    nonisolated static func emitYAML(_ value: Any, indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        switch value {
        case let dict as [String: Any]:
            return dict.sorted(by: { $0.key < $1.key }).map { k, v in
                if let sub = v as? [String: Any], !sub.isEmpty {
                    return pad + k + ":\n" + emitYAML(sub, indent: indent + 2)
                }
                if let arr = v as? [Any], !arr.isEmpty {
                    let itemPad = String(repeating: " ", count: indent + 2)
                    return pad + k + ":\n" + arr.map { item in
                        if let sub = item as? [String: Any], !sub.isEmpty {
                            return itemPad + "-\n" + emitYAML(sub, indent: indent + 4).split(separator: "\n").map { itemPad + "  " + $0 }.joined(separator: "\n")
                        }
                        return itemPad + "- " + emitYAMLScalar(item)
                    }.joined(separator: "\n")
                }
                return pad + k + ": " + emitYAMLScalar(v)
            }.joined(separator: "\n")
        case let arr as [Any]:
            return arr.map { item in
                if let sub = item as? [String: Any], !sub.isEmpty {
                    return pad + "-\n" + emitYAML(sub, indent: indent + 2)
                }
                return pad + "- " + emitYAMLScalar(item)
            }.joined(separator: "\n")
        default:
            return pad + emitYAMLScalar(value)
        }
    }

    /// True if emitting this string unquoted would make YAML interpret it as number, bool, or null.
    private nonisolated static func stringLooksLikeYAMLScalar(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        if t == "null" || t == "true" || t == "false" || t == "yes" || t == "no" { return true }
        var i = t.unicodeScalars.startIndex
        if i == t.unicodeScalars.endIndex { return false }
        if t.unicodeScalars[i] == "-" { i = t.unicodeScalars.index(after: i) }
        if i == t.unicodeScalars.endIndex { return false }
        var hasDigit = false
        var hasDot = false
        while i != t.unicodeScalars.endIndex {
            let c = t.unicodeScalars[i]
            if c == "." {
                if hasDot { return false }
                hasDot = true
            } else if c == "e" || c == "E" {
                i = t.unicodeScalars.index(after: i)
                if i != t.unicodeScalars.endIndex && (t.unicodeScalars[i] == "+" || t.unicodeScalars[i] == "-") {
                    i = t.unicodeScalars.index(after: i)
                }
                while i != t.unicodeScalars.endIndex && CharacterSet.decimalDigits.contains(t.unicodeScalars[i]) {
                    hasDigit = true
                    i = t.unicodeScalars.index(after: i)
                }
                return hasDigit && i == t.unicodeScalars.endIndex
            } else if CharacterSet.decimalDigits.contains(c) {
                hasDigit = true
            } else {
                return false
            }
            i = t.unicodeScalars.index(after: i)
        }
        return hasDigit
    }

    private nonisolated static func emitYAMLScalar(_ value: Any) -> String {
        switch value {
        case let q as YAMLQuotedString:
            switch q.style {
            case .single:
                return "'" + q.value.replacingOccurrences(of: "'", with: "''") + "'"
            case .double:
                return "\"" + q.value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
            }
        case is NSNull:
            return "null"
        case let b as Bool:
            return b ? "true" : "false"
        case let n as Int:
            return String(n)
        case let n as Double:
            return String(n)
        case let s as String:
            if s.contains("\n") || s.contains(":") || s.contains("#") { return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
            if stringLooksLikeYAMLScalar(s) { return "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
            return s
        default:
            return String(describing: value)
        }
    }

    nonisolated static func parseYAML(_ s: String) -> Any? {
        let lines = s.components(separatedBy: .newlines)
        var i = 0
        return parseYAMLBlock(lines, &i, baseIndent: 0)
    }

    /// Recursively replace YAMLQuotedString with its string value for JSON serialization.
    nonisolated static func anyToJSONCompatible(_ value: Any) -> Any {
        switch value {
        case let q as YAMLQuotedString:
            return q.value
        case let d as [String: Any]:
            return d.mapValues { anyToJSONCompatible($0) }
        case let a as [Any]:
            return a.map { anyToJSONCompatible($0) }
        default:
            return value
        }
    }

    private nonisolated static func parseYAMLBlock(_ lines: [String], _ index: inout Int, baseIndent: Int) -> Any? {
        var map: [String: Any] = [:]
        var list: [Any] = []
        var isList = false
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { index += 1; continue }
            let lead = line.prefix(while: { $0 == " " }).count
            if lead < baseIndent { break }
            let content = String(line.dropFirst(lead))
            let contentTrimmed = content.trimmingCharacters(in: .whitespaces)
            if contentTrimmed == "-" || contentTrimmed.hasPrefix("- ") {
                isList = true
                let itemStr: String
                if contentTrimmed == "-" {
                    itemStr = ""
                } else {
                    itemStr = String(contentTrimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                let nextLead = (index < lines.count) ? lines[index].prefix(while: { $0 == " " }).count : 0
                if itemStr.isEmpty, nextLead > lead, index < lines.count, let sub = parseYAMLBlock(lines, &index, baseIndent: nextLead) {
                    list.append(sub)
                } else {
                    list.append(parseYAMLScalar(itemStr))
                }
            } else if let colonIdx = contentTrimmed.firstIndex(of: ":") {
                let key = String(contentTrimmed[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                let rest = String(contentTrimmed[contentTrimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                index += 1
                if rest.isEmpty {
                    let nextLead = (index < lines.count) ? lines[index].prefix(while: { $0 == " " }).count : 0
                    if nextLead > lead, index < lines.count {
                        if let sub = parseYAMLBlock(lines, &index, baseIndent: nextLead) {
                            map[key] = sub
                        }
                    } else {
                        map[key] = NSNull()
                    }
                } else {
                    map[key] = parseYAMLScalar(rest)
                }
            } else {
                index += 1
            }
        }
        if isList { return list }
        return map.isEmpty ? nil : map
    }

    private nonisolated static func parseYAMLScalar(_ s: String) -> Any {
        let t = s.trimmingCharacters(in: .whitespaces)
        // Quoted scalars first so e.g. '1.7' stays a string, not a number
        if t.hasPrefix("\""), t.hasSuffix("\"") {
            let unescaped = String(t.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
            return YAMLQuotedString(value: unescaped, style: .double)
        }
        if t.hasPrefix("'"), t.hasSuffix("'"), t.count >= 2 {
            let unescaped = String(t.dropFirst().dropLast())
                .replacingOccurrences(of: "''", with: "'")
            return YAMLQuotedString(value: unescaped, style: .single)
        }
        if t == "null" || t == "~" { return NSNull() }
        if t == "true" { return true }
        if t == "false" { return false }
        if let i = Int(t) { return i }
        if let d = Double(t) { return d }
        return t
    }

    // MARK: - Minified format parser ({key: value, ...} / [a, b, c])

    /// Parse minified YAML string like {key: value, array: [a, b]}. Returns [String: Any], [Any], or nil.
    nonisolated static func parseMinifiedYAML(_ s: String) -> Any? {
        var i = s.startIndex
        skipMinifiedWS(s, &i)
        guard i < s.endIndex else { return nil }
        if s[i] == "{" {
            return parseMinifiedObject(s, &i)
        }
        if s[i] == "[" {
            return parseMinifiedArray(s, &i)
        }
        return nil
    }

    private nonisolated static func skipMinifiedWS(_ s: String, _ i: inout String.Index) {
        while i < s.endIndex, s[i].isWhitespace { i = s.index(after: i) }
    }

    private nonisolated static func parseMinifiedObject(_ s: String, _ i: inout String.Index) -> [String: Any]? {
        guard i < s.endIndex, s[i] == "{" else { return nil }
        i = s.index(after: i)
        var result: [String: Any] = [:]
        while true {
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "}" {
                i = s.index(after: i)
                return result
            }
            guard let key = parseMinifiedKey(s, &i) else { return nil }
            skipMinifiedWS(s, &i)
            guard i < s.endIndex, s[i] == ":" else { return nil }
            i = s.index(after: i)
            skipMinifiedWS(s, &i)
            guard let value = parseMinifiedValue(s, &i) else { return nil }
            result[key] = value
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return result }
            if s[i] == "}" {
                i = s.index(after: i)
                return result
            }
            if s[i] == "," {
                i = s.index(after: i)
            } else {
                return nil
            }
        }
    }

    private nonisolated static func parseMinifiedArray(_ s: String, _ i: inout String.Index) -> [Any]? {
        guard i < s.endIndex, s[i] == "[" else { return nil }
        i = s.index(after: i)
        var result: [Any] = []
        while true {
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "]" {
                i = s.index(after: i)
                return result
            }
            guard let value = parseMinifiedValue(s, &i) else { return nil }
            result.append(value)
            skipMinifiedWS(s, &i)
            guard i < s.endIndex else { return result }
            if s[i] == "]" {
                i = s.index(after: i)
                return result
            }
            if s[i] == "," {
                i = s.index(after: i)
            } else {
                return nil
            }
        }
    }

    private nonisolated static func parseMinifiedKey(_ s: String, _ i: inout String.Index) -> String? {
        if i < s.endIndex && (s[i] == "'" || s[i] == "\"") {
            guard let any = parseMinifiedQuotedString(s, &i), let q = any as? YAMLQuotedString else { return nil }
            return q.value
        }
        return parseMinifiedUnquoted(s, &i, terminators: ":")
    }

    private nonisolated static func parseMinifiedValue(_ s: String, _ i: inout String.Index) -> Any? {
        guard i < s.endIndex else { return nil }
        let c = s[i]
        if c == "{" {
            return parseMinifiedObject(s, &i)
        }
        if c == "[" {
            return parseMinifiedArray(s, &i)
        }
        if c == "'" || c == "\"" {
            return parseMinifiedQuotedString(s, &i)
        }
        return parseMinifiedUnquotedScalar(s, &i)
    }

    private nonisolated static func parseMinifiedQuotedString(_ s: String, _ i: inout String.Index) -> Any? {
        guard i < s.endIndex else { return nil }
        let quote = s[i]
        guard quote == "'" || quote == "\"" else { return nil }
        i = s.index(after: i)
        var result = ""
        while i < s.endIndex {
            if s[i] == quote {
                if s.index(after: i) < s.endIndex && s[s.index(after: i)] == quote {
                    result.append(quote)
                    i = s.index(i, offsetBy: 2)
                } else {
                    i = s.index(after: i)
                    let style: YAMLQuoteStyle = quote == "'" ? .single : .double
                    return YAMLQuotedString(value: result, style: style)
                }
            } else if quote == "\"" && s[i] == "\\" && s.index(after: i) < s.endIndex {
                let next = s[s.index(after: i)]
                if next == "\"" { result.append("\"") }
                else if next == "\\" { result.append("\\") }
                else { result.append(next) }
                i = s.index(i, offsetBy: 2)
            } else {
                result.append(s[i])
                i = s.index(after: i)
            }
        }
        return nil
    }

    /// Read unquoted scalar until we hit one of the terminator characters.
    private nonisolated static func parseMinifiedUnquoted(_ s: String, _ i: inout String.Index, terminators: String) -> String? {
        let start = i
        while i < s.endIndex, !terminators.contains(s[i]) {
            i = s.index(after: i)
        }
        return String(s[start..<i]).trimmingCharacters(in: .whitespaces)
    }

    private nonisolated static func parseMinifiedUnquotedScalar(_ s: String, _ i: inout String.Index) -> Any? {
        let start = i
        while i < s.endIndex {
            let c = s[i]
            if c == "," || c == "}" || c == "]" {
                break
            }
            i = s.index(after: i)
        }
        let raw = String(s[start..<i]).trimmingCharacters(in: .whitespaces)
        return parseYAMLScalar(raw)
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

    // MARK: - Secure random helpers

    private static func secureRandomBytes(count: Int) -> Data? {
        var data = Data(count: count)
        let success = data.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return false }
            return SecRandomCopyBytes(kSecRandomDefault, count, base) == errSecSuccess
        }
        return success ? data : nil
    }

    /// 32 hex chars (16 bytes) or 64 hex chars (32 bytes).
    static func randomHexString(byteCount: Int) -> String? {
        guard let data = secureRandomBytes(count: byteCount) else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }

    /// ULID: 26 chars, Crockford base32, 48-bit timestamp + 80-bit random.
    private static let ulidAlphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    static func randomULID() -> String? {
        let ms = UInt64(Date().timeIntervalSince1970 * 1000)
        guard let randomPart = secureRandomBytes(count: 10) else { return nil }
        var bytes: [UInt8] = []
        bytes.append(UInt8((ms >> 40) & 0xFF))
        bytes.append(UInt8((ms >> 32) & 0xFF))
        bytes.append(UInt8((ms >> 24) & 0xFF))
        bytes.append(UInt8((ms >> 16) & 0xFF))
        bytes.append(UInt8((ms >> 8) & 0xFF))
        bytes.append(UInt8(ms & 0xFF))
        bytes.append(contentsOf: randomPart)
        // Encode 16 bytes = 128 bits as 26 base32 chars (5 bits per char; last char = 3 data bits + 2 zero padding)
        var result = ""
        var bitBuffer = 0
        var bitCount = 0
        for b in bytes {
            bitBuffer = (bitBuffer << 8) | Int(b)
            bitCount += 8
            while bitCount >= 5 {
                let shift = bitCount - 5
                result.append(ulidAlphabet[(bitBuffer >> shift) & 0x1F])
                bitBuffer &= (1 << shift) - 1
                bitCount = shift
            }
        }
        if bitCount > 0 {
            result.append(ulidAlphabet[(bitBuffer << (5 - bitCount)) & 0x1F])
        }
        return result.count == 26 ? result : nil
    }

    /// NanoID: URL-safe alphanumeric, default 21 chars.
    private static let nanoidAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    static func randomNanoID(length: Int = 21) -> String? {
        guard let data = secureRandomBytes(count: length) else { return nil }
        return data.map { nanoidAlphabet[Int($0) % nanoidAlphabet.count] }.map(String.init).joined()
    }

    /// Very complex: 20 chars from upper, lower, digits, and symbols.
    static func randomVeryComplexPassword(length: Int = 20) -> String? {
        let upper = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let lower = Array("abcdefghijklmnopqrstuvwxyz")
        let digits = Array("0123456789")
        let symbols = Array("!@#$%^&*()_+-=[]{}|;:,.<>?")
        let all = upper + lower + digits + symbols
        guard let data = secureRandomBytes(count: length), data.count >= 4 else { return nil }
        var chars = data.map { all[Int($0) % all.count] }
        chars[0] = upper[Int(data[0]) % upper.count]
        chars[1] = lower[Int(data[1]) % lower.count]
        chars[2] = digits[Int(data[2]) % digits.count]
        chars[3] = symbols[Int(data[3]) % symbols.count]
        return String(chars)
    }

    /// Complex: 20 lowercase alphanumeric in groups of 5 with hyphens (e.g. or2at-23adr-2jASe9-cacTr3 -> 5-5-5-5).
    static func randomComplexPassword(length: Int = 20) -> String? {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        guard let data = secureRandomBytes(count: length) else { return nil }
        let chars = data.map { alphabet[Int($0) % alphabet.count] }
        let s = String(chars)
        let g = 5
        return stride(from: 0, to: s.count, by: g).map { i in String(s[s.index(s.startIndex, offsetBy: i)..<s.index(s.startIndex, offsetBy: min(i + g, s.count))]) }.joined(separator: "-")
    }

    /// Alphanumeric: 20 chars, mixed case + digits.
    static func randomAlphanumericPassword(length: Int = 20) -> String? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        guard let data = secureRandomBytes(count: length) else { return nil }
        return String(data.map { alphabet[Int($0) % alphabet.count] })
    }

    static let loremIpsumPlaceholderShort = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    static let loremIpsumPlaceholderMedium = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat."
    static let loremIpsumPlaceholderFull = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Mauris nec tortor eget mi eleifend tristique. Proin a faucibus arcu, ac suscipit turpis. Sed luctus sagittis nunc, cursus viverra risus rhoncus lobortis. Donec commodo imperdiet hendrerit. Maecenas egestas tristique erat nec condimentum. Donec eget congue magna, at pulvinar enim. Donec convallis mauris libero, vulputate fermentum elit pulvinar a.\n\nVestibulum dolor ipsum, gravida ac cursus ac, venenatis vitae ex. Morbi suscipit pellentesque erat, a interdum felis. Ut a molestie neque. Phasellus euismod nulla sed nisl dignissim lacinia. Donec sit amet sagittis dolor, id blandit est. Vivamus mollis pulvinar felis, sed laoreet lorem ornare eget. Curabitur nec gravida lacus, non feugiat sem. Nunc dapibus porttitor erat quis accumsan. Fusce aliquet ultricies ante, sed facilisis lectus efficitur eu. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Ut pretium nisi id tristique porta.\n\nDuis eu accumsan mauris. Praesent et ex vulputate, imperdiet diam sit amet, auctor nibh. In felis ex, accumsan vitae rutrum sed, congue vitae metus. Nam dictum fringilla hendrerit. Integer finibus eget felis in iaculis. Nam ac tortor in nunc tincidunt pharetra ut at enim. Phasellus in vulputate orci. Cras hendrerit faucibus arcu, id sodales leo luctus ac. Cras accumsan diam semper lacus consequat vehicula. In vel euismod felis, at cursus est. Morbi feugiat viverra porta. Aenean sit amet lectus sit amet ipsum iaculis luctus ut vulputate erat. Aliquam imperdiet accumsan ipsum sed laoreet. Mauris et augue mollis, scelerisque urna id, porta orci. Interdum et malesuada fames ac ante ipsum primis in faucibus. Etiam pellentesque, tortor at elementum feugiat, metus lacus pharetra nisi, eu rutrum est ipsum sit amet magna.\n\nMorbi lacinia nisi vel tempor feugiat. Integer orci nisi, gravida sit amet interdum quis, blandit et neque. Ut eleifend rutrum mi. Vestibulum metus odio, fringilla et commodo sed, ultrices nec elit. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque tempus facilisis quam, ut dignissim lectus blandit in. Etiam metus mauris, feugiat a nisl in, elementum lobortis dolor. Nulla facilisi. Vivamus fermentum feugiat lacus. Mauris sit amet felis ligula. Etiam malesuada, nulla quis sollicitudin egestas, lorem lacus ullamcorper diam, non varius massa lacus vel erat. Fusce eleifend rutrum dolor, sed maximus urna ornare sit amet. Vestibulum ut ex mattis lectus pellentesque convallis at et lectus.\n\nDuis sit amet consequat diam. Proin eu vulputate mauris. Nam tincidunt dictum fringilla. Duis ut pellentesque orci. Vivamus vestibulum pharetra pharetra. Quisque viverra pellentesque risus, tempus finibus erat maximus sit amet. Nullam consequat venenatis turpis sed dapibus. Pellentesque aliquam vel felis et gravida. Fusce faucibus, tellus ac malesuada dignissim, metus urna aliquet lacus, ac lobortis nisl dolor egestas nunc. Praesent magna nisl, gravida vel imperdiet sit amet, eleifend vitae dolor. Suspendisse sit amet turpis ultricies, aliquam leo eget, egestas magna. Vivamus non congue ante."

    static let quickBrownFoxPlaceholder = "The quick brown fox jumps over the lazy dog"
    static let packMyBoxPlaceholder = "Pack my box with five dozen liquor jugs."
    static let sphinxOfBlackQuartzPlaceholder = "Sphinx of black quartz, judge my vow."
    static let waltzBadNymphPlaceholder = "Waltz, bad nymph, for quick jigs vex!"
    static let jackdawsPlaceholder = "Jackdaws love my big sphinx of quartz."
}



