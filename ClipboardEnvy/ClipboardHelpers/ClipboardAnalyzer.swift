import Foundation

/// Detected clipboard data type, ordered by detection priority (faster/simpler checks first).
enum ClipboardDataType: String, CaseIterable {
    case nonText = "Non-Text"
    case url = "URL"
    case jwt = "JWT"
    case time = "Time"
    case base64 = "Base64 String"
    case base64URL = "Base64 String (URL-Safe)"
    case json = "JSON"
    case csv = "CSV"
    case tsv = "TSV"
    case psv = "PSV"
    case yaml = "YAML"
    case fixedWidthTable = "Table"
    case databaseCLITable = "Database CLI Table"
    case binaryValue = "Binary Value"
    case hexadecimal = "Hexadecimal Value"
    case integer = "Integer"
    case decimal = "Decimal"
    case generalText = "General Text"
}

/// Result of clipboard analysis with type-safe access to detected properties.
/// Uses ordered array to preserve insertion order for display.
/// Explicitly not ``MainActor`` so analysis can run off the UI actor despite the module default.
nonisolated struct ClipboardAnalysis {
    /// Marker key for legacy `displayItems` composition (divider before counts).
    static let dividerKey = "---"
    /// Empty key in `displayItems` means show `value` only (e.g. multiline preview rows).
    static let valueOnlyKey = ""

    let dataType: ClipboardDataType
    private var orderedProperties: [(key: String, value: String)] = []
    private var textMetrics: [(key: String, value: String)] = []
    private var previewOnlyLines: [String] = []
    /// True when the clipboard (or decoded preview source) has more non-empty lines than ``previewLines``.
    private(set) var previewHasAdditionalLines: Bool = false

    init(dataType: ClipboardDataType) {
        self.dataType = dataType
    }

    /// Data type plus detected properties (menu **Analysis** section; no section header in UI).
    var analysisDisplayItems: [(key: String, value: String)] {
        [("Data Type", dataType.rawValue)] + orderedProperties
    }

    /// Truncated plaintext-style lines for menu **Preview** section (decoded body for Base64, clipboard text for other types).
    var previewLines: [String] {
        previewOnlyLines
    }

    /// Character/word/line and related metrics (menu **Counts** section; no section header in UI).
    var countDisplayItems: [(key: String, value: String)] {
        textMetrics
    }

    /// Flattened stream for tests and callers that expect a single list (analysis, then preview rows, then counts).
    var displayItems: [(key: String, value: String)] {
        var items = analysisDisplayItems
        for line in previewOnlyLines {
            items.append((Self.valueOnlyKey, line))
        }
        if !textMetrics.isEmpty {
            items.append((Self.dividerKey, ""))
            items.append(contentsOf: textMetrics)
        }
        return items
    }

    mutating func appendPreviewOnlyLines(_ lines: [String]) {
        previewOnlyLines.append(contentsOf: lines)
    }

    mutating func setPreviewHasAdditionalLines(_ value: Bool) {
        previewHasAdditionalLines = previewHasAdditionalLines || value
    }

    mutating func setTextMetric(_ key: String, _ value: String) {
        if let idx = textMetrics.firstIndex(where: { $0.key == key }) {
            textMetrics[idx] = (key, value)
        } else {
            textMetrics.append((key, value))
        }
    }

    subscript(key: String) -> String? {
        get {
            orderedProperties.first { $0.key == key }?.value ??
            textMetrics.first { $0.key == key }?.value
        }
        set {
            if let newValue = newValue {
                if let idx = orderedProperties.firstIndex(where: { $0.key == key }) {
                    orderedProperties[idx] = (key, newValue)
                } else if let idx = textMetrics.firstIndex(where: { $0.key == key }) {
                    textMetrics[idx] = (key, newValue)
                } else {
                    orderedProperties.append((key, newValue))
                }
            } else {
                orderedProperties.removeAll { $0.key == key }
                textMetrics.removeAll { $0.key == key }
            }
        }
    }

    mutating func set(_ key: String, _ value: String) {
        if let idx = orderedProperties.firstIndex(where: { $0.key == key }) {
            orderedProperties[idx] = (key, value)
        } else if let idx = textMetrics.firstIndex(where: { $0.key == key }) {
            textMetrics[idx] = (key, value)
        } else {
            orderedProperties.append((key, value))
        }
    }

    /// Convenience accessor for line count from analysis.
    var lineCount: Int {
        guard let linesStr = self["Lines"], let count = Int(linesStr) else { return 1 }
        return count
    }

    /// Convenience accessor for database CLI format (e.g., "MySQL CLI", "psql", "sqlite3", "ClickHouse CLI").
    var databaseFormat: String? {
        self["Format"]
    }

    /// Convenience accessor for detected fixed-width / CLI-style table type (e.g., "Docker Containers List").
    var tableTypeName: String? {
        self["Table Type"]
    }

    /// True when analysis represents any tabular data type with columnar structure.
    var isTableLike: Bool {
        dataType == .fixedWidthTable || dataType == .databaseCLITable || isDelimitedData
    }

    /// Convenience accessor for detected time format (e.g., "Epoch Seconds", "RFC3339 / ISO8601").
    var timeFormat: String? {
        self["Detected Format"]
    }

    // MARK: - URL Part Accessors

    var urlHasUsername: Bool {
        self["Username"] != nil
    }

    var urlHasPassword: Bool {
        self["Password"] != nil
    }

    var urlHasPort: Bool {
        self["Port"] != nil
    }

    var urlHasPath: Bool {
        self["Path"] != nil
    }

    var urlHasQuery: Bool {
        self["Query Params"] != nil
    }

    var urlHasFragment: Bool {
        self["Fragment"] != nil
    }

    // MARK: - Text Content Flags

    var hasCarriageReturns: Bool {
        self["Has CRLF"] == "Yes"
    }

    var isArrayStructure: Bool {
        self["Structure"] == "Array"
    }

    var isMinified: Bool {
        self["Minified"] == "Yes"
    }

    var isDelimitedData: Bool {
        dataType == .csv || dataType == .tsv || dataType == .psv
    }

    var isPossiblyURLEncoded: Bool {
        self["URL Encoded"] == "Yes"
    }

    /// Convenience accessor for counted zero-width characters in the analyzed text.
    var zeroWidthCharacterCount: Int {
        guard let value = self["Zero-width Characters"], let n = Int(value) else { return 0 }
        return n
    }

}

/// Clipboard content analyzer for type detection and type-specific analysis.
enum ClipboardAnalyzer {

    /// Analyze clipboard text content and return structured analysis.
    /// - Parameters:
    ///   - text: Clipboard string, or nil when non-text.
    ///   - menuLabelMaxChars: Max characters per preview line (same semantics as snippet menu titles); clamped to 10...64.
    ///   - clipboardPreviewMaxLines: Max non-empty preview lines in the analysis menu; clamped to 0...20.
    static func analyze(_ text: String?, menuLabelMaxChars: Int = 36, clipboardPreviewMaxLines: Int = 5) -> ClipboardAnalysis {
        guard let text = text else {
            return ClipboardAnalysis(dataType: .nonText)
        }

        let maxLineLen = min(max(menuLabelMaxChars, 10), 64)
        let previewMaxLines = min(max(clipboardPreviewMaxLines, 0), 20)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return finish(analyzeGeneralText(text), sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines)
        }

        if let analysis = detectJWT(trimmed, original: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectURL(trimmed, original: text, maxLineLen: maxLineLen) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        // Before Time: numeric-looking bit strings (e.g. `10101010`) must not be parsed as epoch values.
        if let analysis = detectBinaryValue(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectTime(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectBase64URL(trimmed, original: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectBase64(trimmed, original: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        // Before hex so digit-only values like `2048` are Integer, not hex nibbles.
        if let analysis = detectPlainNumber(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectHexadecimal(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectJSON(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectDatabaseCLITable(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectFixedWidthTable(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectCSV(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectTSV(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectPSV(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }
        if let analysis = detectYAML(trimmed, original: text) { return finish(analysis, sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines) }

        return finish(analyzeGeneralText(text), sourceText: text, maxLineLen: maxLineLen, previewMaxLines: previewMaxLines)
    }

    private static func finish(_ analysis: ClipboardAnalysis, sourceText: String, maxLineLen: Int, previewMaxLines: Int) -> ClipboardAnalysis {
        var a = analysis
        if previewMaxLines > 0, shouldAppendPlaintextStylePreview(for: a.dataType) {
            let (lines, hasMore) = buildPreviewLines(from: sourceText, maxLineLength: maxLineLen, maxLines: previewMaxLines)
            a.appendPreviewOnlyLines(lines)
            a.setPreviewHasAdditionalLines(hasMore)
        }
        return a
    }

    private static func shouldAppendPlaintextStylePreview(for dataType: ClipboardDataType) -> Bool {
        switch dataType {
        case .nonText, .jwt, .base64, .base64URL:
            return false
        default:
            return true
        }
    }

    /// First up to `maxLines` non-empty lines (by trimming whitespace/newlines), each truncated like snippet menu titles.
    /// When every preview line begins with the same kind of indent (all spaces or all tabs matching the first line’s first character),
    /// removes that common prefix from each line before truncation so the menu shows more content and less gutter.
    /// - Returns: Lines to show, and whether another non-empty line exists after those.
    private static func buildPreviewLines(from text: String, maxLineLength: Int, maxLines: Int) -> (lines: [String], hasAdditionalNonEmptyLines: Bool) {
        guard maxLines > 0 else { return ([], false) }
        var rawLines: [String] = []
        var hasAdditionalNonEmptyLines = false
        for line in text.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            if rawLines.count < maxLines {
                rawLines.append(line)
            } else {
                hasAdditionalNonEmptyLines = true
                break
            }
        }
        let dedented = dedentHomogeneousLeadingIndent(rawLines)
        let lines = dedented.map { truncateForMenuLabel($0, limit: maxLineLength) }
        return (lines, hasAdditionalNonEmptyLines)
    }

    /// Strips the same count of leading `matchChar` (space or tab) from every line, where `matchChar` is taken from the first
    /// character of the first line and `indentSize` is the minimum leading run of that character across lines.
    private static func dedentHomogeneousLeadingIndent(_ lines: [String]) -> [String] {
        guard let first = lines.first, let matchChar = first.first, matchChar == " " || matchChar == "\t" else {
            return lines
        }
        let counts = lines.map { countLeadingCharacters($0, matching: matchChar) }
        let indentSize = counts.min() ?? 0
        guard indentSize > 0 else { return lines }
        return lines.map { String($0.dropFirst(indentSize)) }
    }

    private static func countLeadingCharacters(_ s: String, matching matchChar: Character) -> Int {
        var n = 0
        for ch in s {
            if ch == matchChar { n += 1 } else { break }
        }
        return n
    }

    private static func truncateForMenuLabel(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]) + "…"
    }

    // MARK: - Type Detection

    private static func jwtPayloadClaimDisplayString(key: String, value: Any) -> String {
        if let stringValue = value as? String {
            return stringValue
        }
        if let numValue = value as? NSNumber {
            if isTimestampClaim(key), let date = dateFromTimestamp(numValue) {
                return formatTimestampLocal(date)
            }
            return "\(numValue)"
        }
        if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        }
        if let arrayValue = value as? [Any] {
            let items = arrayValue.compactMap { item -> String? in
                if let s = item as? String { return s }
                if let n = item as? NSNumber { return "\(n)" }
                return nil
            }
            return items.joined(separator: ", ")
        }
        return String(describing: value)
    }

    private static func detectJWT(_ trimmed: String, original: String, maxLineLen: Int, previewMaxLines: Int) -> ClipboardAnalysis? {
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }

        let headerPart = String(parts[0])
        let payloadPart = String(parts[1])

        guard let headerData = base64URLDecodeToData(headerPart),
              let headerJSON = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              headerJSON["alg"] != nil || headerJSON["typ"] != nil else {
            return nil
        }

        var analysis = ClipboardAnalysis(dataType: .jwt)
        addTextMetrics(to: &analysis, text: original)

        if let alg = headerJSON["alg"] as? String {
            analysis.set("Algorithm", alg)
        }
        if let typ = headerJSON["typ"] as? String {
            analysis.set("Type", typ)
        }

        if previewMaxLines > 0,
           let payloadData = base64URLDecodeToData(payloadPart),
           let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            var lines: [String] = []
            let sortedClaims = payloadJSON.sorted(by: { $0.key < $1.key })
            for (key, value) in sortedClaims {
                guard lines.count < previewMaxLines else { break }
                let valueStr = jwtPayloadClaimDisplayString(key: key, value: value)
                let line = "\(key): \(valueStr)"
                lines.append(truncateForMenuLabel(line, limit: maxLineLen))
            }
            analysis.appendPreviewOnlyLines(lines)
            analysis.setPreviewHasAdditionalLines(sortedClaims.count > lines.count)
        }

        return analysis
    }

    private static func detectURL(_ trimmed: String, original: String, maxLineLen: Int) -> ClipboardAnalysis? {
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else { return nil }
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: firstLine), url.host != nil else { return nil }

        var analysis = ClipboardAnalysis(dataType: .url)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Scheme", url.scheme ?? "")
        if let user = url.user, !user.isEmpty {
            analysis.set("Username", truncateForMenuLabel(user, limit: maxLineLen))
            if let password = url.password, !password.isEmpty {
                analysis.set("Password", "••••••••")
            }
        }
        if let host = url.host {
            analysis.set("Host", truncateForMenuLabel(host, limit: maxLineLen))
        }
        if let port = url.port {
            analysis.set("Port", "\(port)")
        }
        if !url.path.isEmpty && url.path != "/" {
            analysis.set("Path", truncateForMenuLabel(url.path, limit: maxLineLen))
        }
        if let query = url.query, !query.isEmpty {
            analysis.set("Query Params", "\(query.components(separatedBy: "&").count)")
        }
        if let fragment = url.fragment, !fragment.isEmpty {
            analysis.set("Fragment", truncateForMenuLabel(fragment, limit: maxLineLen))
        }

        return analysis
    }

    private static func detectTime(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard let (date, formatName) = parseTimeWithFormat(trimmed) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .time)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Detected Format", formatName)
        analysis.set("Local", formatTimestampLocal(date))
        analysis.set("UTC", formatTimestampUTC(date))

        return analysis
    }

    private static let binaryValueMaxUTF8Bytes = 1024

    /// Bit patterns: `0`/`1` only, optional single-kind whitespace (` ` *or* `\t`) as byte separators; or contiguous with length ≥ 16 and multiple of 8.
    private static func detectBinaryValue(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard trimmed.utf8.count < binaryValueMaxUTF8Bytes else { return nil }
        if trimmed.contains("\n") || trimmed.contains("\r") { return nil }

        var had0bPrefix = false
        var bitPayload = trimmed
        if bitPayload.lowercased().hasPrefix("0b") {
            had0bPrefix = true
            bitPayload = String(bitPayload.dropFirst(2))
            guard !bitPayload.isEmpty else { return nil }
        }

        let hasSpace = bitPayload.contains(" ")
        let hasTab = bitPayload.contains("\t")
        if hasSpace && hasTab { return nil }
        guard bitPayload.unicodeScalars.allSatisfy({ s in
            s == "0" || s == "1" || s == " " || s == "\t"
        }) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .binaryValue)
        addTextMetrics(to: &analysis, text: original)

        if hasSpace || hasTab {
            let separator: Character = hasSpace ? " " : "\t"
            let parts = bitPayload.split(whereSeparator: { $0 == separator }).map(String.init)
            guard parts.count >= 2 else { return nil }
            guard let first = parts.first,
                  (1...8).contains(first.count),
                  first.unicodeScalars.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
            guard parts.dropFirst().allSatisfy({ p in
                p.count == 8 && p.unicodeScalars.allSatisfy { $0 == "0" || $0 == "1" }
            }) else { return nil }
            guard let bytes = binaryDelimitedPartsToBytes(parts) else { return nil }
            analysis.set("Hex Data", formatBinaryBytesAsHexSpaced(bytes))
            if bytes.allSatisfy({ (32...126).contains($0) }),
               let ascii = String(bytes: bytes, encoding: .utf8) {
                analysis.set("ASCII Data", ascii)
            }
            return analysis
        }

        // Contiguous 0/1 only
        guard bitPayload.unicodeScalars.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
        let bitCount = bitPayload.count
        // Unprefixed single-bit strings are decimal digits, not bit patterns (e.g. "0" → Integer).
        if bitCount == 1, !had0bPrefix { return nil }
        if bitCount >= 16, bitCount.isMultiple(of: 8) {
            guard let bytes = binaryContiguousToBytes(bitPayload) else { return nil }
            analysis.set("Hex Data", formatBinaryBytesAsHexSpaced(bytes))
            if bytes.allSatisfy({ (32...126).contains($0) }),
               let ascii = String(bytes: bytes, encoding: .utf8) {
                analysis.set("ASCII Data", ascii)
            }
            return analysis
        }

        if bitCount <= 64, let intVal = binaryStringToUInt64(bitPayload) {
            analysis.set("Integer Value", "\(intVal)")
        }
        return analysis
    }

    private static func binaryDelimitedPartsToBytes(_ parts: [String]) -> [UInt8]? {
        var out: [UInt8] = []
        out.reserveCapacity(parts.count)
        for p in parts {
            guard let b = binaryChunkToUInt8(p) else { return nil }
            out.append(b)
        }
        return out
    }

    private static func binaryContiguousToBytes(_ contiguous: String) -> [UInt8]? {
        var out: [UInt8] = []
        var idx = contiguous.startIndex
        while idx < contiguous.endIndex {
            let end = contiguous.index(idx, offsetBy: 8, limitedBy: contiguous.endIndex) ?? contiguous.endIndex
            guard contiguous.distance(from: idx, to: end) == 8 else { return nil }
            let chunk = String(contiguous[idx..<end])
            guard let b = binaryChunkToUInt8(chunk) else { return nil }
            out.append(b)
            idx = end
        }
        return out
    }

    /// Interprets a 1…8 character `0`/`1` run as the least-significant bits of a byte (`1001000` → 0x48).
    private static func binaryChunkToUInt8(_ chunk: String) -> UInt8? {
        guard !chunk.isEmpty, chunk.count <= 8 else { return nil }
        guard chunk.unicodeScalars.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
        var v: UInt8 = 0
        for ch in chunk.unicodeScalars {
            v = (v << 1) | (ch == "1" ? 1 : 0)
        }
        return v
    }

    private static func binaryStringToUInt64(_ contiguous: String) -> UInt64? {
        guard !contiguous.isEmpty, contiguous.count <= 64 else { return nil }
        guard contiguous.unicodeScalars.allSatisfy({ $0 == "0" || $0 == "1" }) else { return nil }
        var v: UInt64 = 0
        for ch in contiguous.unicodeScalars {
            v = (v << 1) | (ch == "1" ? 1 : 0)
        }
        return v
    }

    private static func formatBinaryBytesAsHexSpaced(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Hexadecimal digit run (0-9, a-f after trim+lowercase), at least 4 characters, detected after Base64 so decodable payloads win.
    /// Even lengths report byte count (half the length) and bit count (bytes × 8).
    private static func detectHexadecimal(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        var normalized = trimmed.lowercased()
        let had0xPrefix = normalized.hasPrefix("0x")
        if had0xPrefix {
            normalized = String(normalized.dropFirst(2))
            guard !normalized.isEmpty else { return nil }
        }
        let minLen = had0xPrefix ? 1 : 4
        guard normalized.count >= minLen, isHexadecimalDigitString(normalized) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .hexadecimal)
        addTextMetrics(to: &analysis, text: original)
        if normalized.count.isMultiple(of: 2) {
            let bytes = normalized.count / 2
            analysis.set("Byte Count", "\(bytes)")
            analysis.set("Bit Count", "\(bytes * 8)")
        }
        return analysis
    }

    /// ASCII `0-9` or `a-f` only (caller passes lowercased+trimmed input).
    private static func isHexadecimalDigitString(_ lowercased: String) -> Bool {
        for scalar in lowercased.unicodeScalars {
            let v = scalar.value
            let isDigit = v >= 0x30 && v <= 0x39
            let isHexLetter = v >= 0x61 && v <= 0x66
            guard isDigit || isHexLetter else { return false }
        }
        return true
    }

    private static func detectBase64URL(_ trimmed: String, original: String, maxLineLen: Int, previewMaxLines: Int) -> ClipboardAnalysis? {
        guard trimmed.count >= 4,
              !trimmed.contains("+"),
              !trimmed.contains("/"),
              trimmed.contains("-") || trimmed.contains("_"),
              isValidBase64URLChars(trimmed) else { return nil }

        guard let decoded = base64URLDecodeToData(trimmed),
              decoded.count >= 1,
              let decodedString = String(data: decoded, encoding: .utf8),
              isPrintableString(decodedString) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .base64URL)
        addTextMetrics(to: &analysis, text: decodedString)
        analysis.set("Encoded Size", "\(original.utf8.count) bytes")
        analysis.set("Decoded Size", "\(decoded.count) bytes")
        let (lines, hasMore) = buildPreviewLines(from: decodedString, maxLineLength: maxLineLen, maxLines: previewMaxLines)
        analysis.appendPreviewOnlyLines(lines)
        analysis.setPreviewHasAdditionalLines(hasMore)

        return analysis
    }

    private static func detectBase64(_ trimmed: String, original: String, maxLineLen: Int, previewMaxLines: Int) -> ClipboardAnalysis? {
        guard trimmed.count >= 4,
              isValidBase64Chars(trimmed) else { return nil }

        let paddedInput = padBase64(trimmed)
        guard let decoded = Data(base64Encoded: paddedInput),
              decoded.count >= 1,
              let decodedString = String(data: decoded, encoding: .utf8),
              isPrintableString(decodedString) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .base64)
        addTextMetrics(to: &analysis, text: decodedString)
        analysis.set("Encoded Size", "\(original.utf8.count) bytes")
        analysis.set("Decoded Size", "\(decoded.count) bytes")
        let (lines, hasMore) = buildPreviewLines(from: decodedString, maxLineLength: maxLineLen, maxLines: previewMaxLines)
        analysis.appendPreviewOnlyLines(lines)
        analysis.setPreviewHasAdditionalLines(hasMore)

        return analysis
    }

    private static func detectJSON(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let firstChar = trimmed.first
        let lastChar = trimmed.last
        guard firstChar == "{" || firstChar == "[" else { return nil }

        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .json)
        addTextMetrics(to: &analysis, text: original)

        // Structure first
        if firstChar == "[" && lastChar == "]" {
            analysis.set("Structure", "Array")
            if let array = json as? [Any] {
                analysis.set("Element Count", "\(array.count)")
                if let firstObj = array.first as? [String: Any] {
                    analysis.set("Object Keys", "\(firstObj.keys.count)")
                }
            }
        } else {
            analysis.set("Structure", "Object")
            if let dict = json as? [String: Any] {
                analysis.set("Key Count", "\(dict.keys.count)")
            }
        }

        // Detect minification: single line after trimming means minified
        let lineCount = trimmed.components(separatedBy: .newlines).count
        analysis.set("Minified", lineCount == 1 ? "Yes" : "No")

        return analysis
    }

    private static func detectDatabaseCLITable(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }

        if let analysis = detectMySQLTable(lines, original: original) { return analysis }
        if let analysis = detectClickHouseTable(trimmed, original: original) { return analysis }
        if let analysis = detectPsqlTable(lines, original: original) { return analysis }
        if let analysis = detectSqlite3Table(lines, original: original) { return analysis }

        return nil
    }

    /// Detects fixed-width, space- or column-aligned tables without explicit borders (e.g., `ps`, `docker ps`, `kubectl get`).
    /// Primarily uses runs of 2+ spaces as delimiters between columns, but falls back to any whitespace
    /// when necessary (for commands that emit single-space-separated columns like short `ps` output).
    private static func detectFixedWidthTable(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let unix = trimmed.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = unix.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return nil }

        let headerLine = lines[0]
        // If the header already contains tab characters, this is more likely a TSV table;
        // let the dedicated TSV detector handle it instead of treating it as fixed-width.
        if headerLine.contains("\t") {
            return nil
        }

        var headerColumns = splitFixedWidthLine(headerLine)
        var useLooseWhitespaceSplit = false
        if headerColumns.count < 3 {
            headerColumns = splitLooseWhitespaceLine(headerLine)
            useLooseWhitespaceSplit = headerColumns.count >= 3
        }
        // Require at least 3 reasonably sized header columns to be considered a table.
        guard headerColumns.count >= 3, headerColumns.count <= 32 else { return nil }

        // If this matches a known table type (e.g. Open Files List), accept it immediately
        // without requiring strict column-count consistency across data rows. Some table
        // formats have optional middle columns that are blank on many lines.
        if let tableType = recognizeKnownTableType(fromHeaderColumns: headerColumns) {
            var analysis = ClipboardAnalysis(dataType: .fixedWidthTable)
            addTextMetrics(to: &analysis, text: original)
            analysis.set("Columns", "\(headerColumns.count)")
            analysis.set("Rows", "\(max(0, lines.count - 1))")
            analysis.set("Table Type", tableType)
            return analysis
        }

        // Ensure at least one data row roughly matches the header column count.
        let dataLines = Array(lines.dropFirst())
        let splitter: (String) -> [String] = useLooseWhitespaceSplit
            ? { line in splitLooseWhitespaceLine(line) }
            : { line in splitFixedWidthLine(line) }
        let dataColumnMatches = dataLines.prefix(10).filter { !splitter($0).isEmpty }.map { splitter($0).count }
        guard let firstCount = dataColumnMatches.first, !dataColumnMatches.isEmpty else { return nil }
        let consistent = dataColumnMatches.allSatisfy { abs($0 - firstCount) <= 1 }
        guard consistent else { return nil }

        var analysis = ClipboardAnalysis(dataType: .fixedWidthTable)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Columns", "\(headerColumns.count)")
        analysis.set("Rows", "\(max(0, lines.count - 1))")

        return analysis
    }

    private static func detectMySQLTable(_ lines: [String], original: String) -> ClipboardAnalysis? {
        let hasBorder = lines.contains { $0.hasPrefix("+") && $0.hasSuffix("+") && $0.contains("-") }
        guard hasBorder else { return nil }

        var analysis = ClipboardAnalysis(dataType: .databaseCLITable)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Format", "MySQL CLI")

        let dataLines = lines.filter { !$0.hasPrefix("+") && $0.contains("|") }
        if dataLines.count > 1 {
            analysis.set("Data Rows", "\(dataLines.count - 1)")
        }
        if let headerLine = dataLines.first {
            let columns = headerLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            analysis.set("Columns", "\(columns.count)")
        }

        return analysis
    }

    private static func detectClickHouseTable(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard let rows = try? ClipboardTransform.clickhouseCliTableRows(trimmed), rows.count >= 2 else { return nil }

        var analysis = ClipboardAnalysis(dataType: .databaseCLITable)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Format", "ClickHouse CLI")
        analysis.set("Columns", "\(rows[0].count)")
        analysis.set("Data Rows", "\(rows.count - 1)")
        return analysis
    }

    private static func detectPsqlTable(_ lines: [String], original: String) -> ClipboardAnalysis? {
        guard lines.count >= 2 else { return nil }
        let separatorIndex = lines.firstIndex { $0.contains("-+-") || ($0.hasPrefix("-") && $0.contains("+")) }
        guard let sepIdx = separatorIndex, sepIdx > 0 else { return nil }

        var analysis = ClipboardAnalysis(dataType: .databaseCLITable)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Format", "psql")

        let headerLine = lines[sepIdx - 1]
        let columns = headerLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        analysis.set("Columns", "\(columns.count)")

        let dataRows = lines.dropFirst(sepIdx + 1).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        analysis.set("Data Rows", "\(dataRows.count)")

        return analysis
    }

    private static func detectSqlite3Table(_ lines: [String], original: String) -> ClipboardAnalysis? {
        guard lines.count >= 2 else { return nil }
        let separatorLine = lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("-") && trimmed.allSatisfy { $0 == "-" || $0 == " " }
        }
        guard separatorLine != nil else { return nil }
        guard let sepIdx = lines.firstIndex(of: separatorLine!), sepIdx > 0 else { return nil }

        var analysis = ClipboardAnalysis(dataType: .databaseCLITable)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Format", "sqlite3")

        let columnCount = separatorLine!.split(separator: " ", omittingEmptySubsequences: true).count
        analysis.set("Columns", "\(columnCount)")

        let dataRows = lines.dropFirst(sepIdx + 1).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        analysis.set("Data Rows", "\(dataRows.count)")

        return analysis
    }

    private static func detectCSV(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let firstLine = lines[0]
        guard firstLine.contains(",") else { return nil }

        let firstLineCommas = firstLine.filter { $0 == "," }.count
        guard firstLineCommas >= 1 else { return nil }

        // Require exact comma consistency across all lines (CSV should be uniform)
        for line in lines.dropFirst() {
            let lineCommas = line.filter { $0 == "," }.count
            guard lineCommas == firstLineCommas else { return nil }
        }

        // Reject if text looks like prose (sentence patterns)
        if looksLikeProse(trimmed) { return nil }

        var analysis = ClipboardAnalysis(dataType: .csv)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Columns", "\(firstLineCommas + 1)")
        analysis.set("Rows", "\(lines.count - 1)")

        return analysis
    }

    private static func detectTSV(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let firstLine = lines[0]
        guard firstLine.contains("\t") else { return nil }

        let firstLineTabs = firstLine.filter { $0 == "\t" }.count
        guard firstLineTabs >= 1 else { return nil }

        // Require exact tab consistency across all lines
        for line in lines.dropFirst() {
            let lineTabs = line.filter { $0 == "\t" }.count
            guard lineTabs == firstLineTabs else { return nil }
        }

        // Reject if text looks like prose
        if looksLikeProse(trimmed) { return nil }

        var analysis = ClipboardAnalysis(dataType: .tsv)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Columns", "\(firstLineTabs + 1)")
        analysis.set("Rows", "\(lines.count - 1)")

        return analysis
    }

    private static func detectPSV(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        let lines = trimmed.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let firstLine = lines[0]
        guard firstLine.contains("|") else { return nil }

        let firstLinePipes = firstLine.filter { $0 == "|" }.count
        guard firstLinePipes >= 1 else { return nil }

        // Require exact pipe consistency across all lines
        for line in lines.dropFirst() {
            let linePipes = line.filter { $0 == "|" }.count
            guard linePipes == firstLinePipes else { return nil }
        }

        // Reject if text looks like prose
        if looksLikeProse(trimmed) { return nil }

        var analysis = ClipboardAnalysis(dataType: .psv)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Columns", "\(firstLinePipes + 1)")
        analysis.set("Rows", "\(lines.count - 1)")

        return analysis
    }

    private static func detectYAML(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        // Intentionally no looksLikeProse here: self-documented YAML often has many full-sentence
        // `#` comments that match the prose heuristic. Structured YAML detection relies on
        // YAMLHelpers.parsesAsStructuredYAMLDocument instead.

        let hasJsonStart = trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
        guard !hasJsonStart else { return nil }

        // Require a successful parse under the same block parser as transforms, with strict line/key rules
        // so Swift and other code with `name: value` fragments is not labeled YAML.
        guard YAMLHelpers.parsesAsStructuredYAMLDocument(trimmed) else { return nil }

        let lines = trimmed.components(separatedBy: .newlines)

        var analysis = ClipboardAnalysis(dataType: .yaml)
        addTextMetrics(to: &analysis, text: original)

        // Detect minification: single line after trimming means minified (rare for YAML but possible)
        let lineCount = trimmed.components(separatedBy: .newlines).count
        analysis.set("Minified", lineCount == 1 ? "Yes" : "No")

        let firstStructuralLine = lines.lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { t in
                !t.isEmpty && !t.hasPrefix("#") && !YAMLHelpers.isYAMLStreamMarkerLine(t)
            }
        let isArrayStyle = firstStructuralLine.map { $0 == "-" || $0.hasPrefix("- ") } ?? false
        analysis.set("Structure", isArrayStyle ? "Array" : "Object")

        return analysis
    }

    private static func detectPlainNumber(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard trimmed.rangeOfCharacter(from: .newlines) == nil else { return nil }
        // Binary rejects at `binaryValueMaxUTF8Bytes`; long 0/1-only runs are better as hex (or remain non-integer).
        if trimmed.utf8.count >= binaryValueMaxUTF8Bytes,
           trimmed.unicodeScalars.allSatisfy({ $0 == "0" || $0 == "1" }) {
            return nil
        }
        let lonePrefix = trimmed.lowercased()
        guard lonePrefix != "0x", lonePrefix != "0b" else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ ("0"..."9").contains($0) || $0 == "-" || $0 == "." }) else { return nil }
        guard trimmed.filter({ $0 == "-" }).count <= 1, !trimmed.dropFirst().contains("-") else { return nil }

        let locale = Locale(identifier: "en_US_POSIX")
        if matchesPlainInteger(trimmed) {
            guard let dec = Decimal(string: trimmed, locale: locale) else { return nil }
            var analysis = ClipboardAnalysis(dataType: .integer)
            addTextMetrics(to: &analysis, text: original)
            ClipboardNumberAnalysis.apply(to: &analysis, value: dec, rawInput: trimmed, flavor: .integer)
            return analysis
        }
        if matchesPlainDecimal(trimmed) {
            guard let dec = Decimal(string: trimmed, locale: locale) else { return nil }
            var analysis = ClipboardAnalysis(dataType: .decimal)
            addTextMetrics(to: &analysis, text: original)
            ClipboardNumberAnalysis.apply(to: &analysis, value: dec, rawInput: trimmed, flavor: .decimal)
            return analysis
        }
        return nil
    }

    private static func matchesPlainInteger(_ s: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: "^-?[0-9]+$") else { return false }
        let range = NSRange(s.startIndex..., in: s)
        return re.firstMatch(in: s, options: [], range: range)?.range == range
    }

    private static func matchesPlainDecimal(_ s: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: "^-?[0-9]+\\.[0-9]+$") else { return false }
        let range = NSRange(s.startIndex..., in: s)
        return re.firstMatch(in: s, options: [], range: range)?.range == range
    }

    private static func analyzeGeneralText(_ text: String) -> ClipboardAnalysis {
        var analysis = ClipboardAnalysis(dataType: .generalText)
        addTextMetrics(to: &analysis, text: text)
        return analysis
    }

    // MARK: - Helpers

    private static func addTextMetrics(to analysis: inout ClipboardAnalysis, text: String) {
        // Check for URL-encoded content first - if so, use decoded text for metrics
        let isURLEncoded = isPossiblyURLEncoded(text)
        let metricsText: String
        if isURLEncoded {
            let decoded = text.removingPercentEncoding ?? text
            metricsText = decoded
            analysis.set("URL Encoded", "Yes")
            analysis.set("Encoded Size", "\(text.utf8.count) bytes")
            analysis.set("Decoded Size", "\(decoded.utf8.count) bytes")
        } else {
            metricsText = text
        }

        // Text metrics go in a separate section at the bottom (based on decoded text if URL-encoded)
        analysis.setTextMetric("Characters", "\(metricsText.count)")
        let words = metricsText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        analysis.setTextMetric("Words", "\(words.count)")
        let lines = metricsText.components(separatedBy: .newlines)
        let lineCount = metricsText.hasSuffix("\n") ? lines.count : max(1, lines.count)
        analysis.setTextMetric("Lines", "\(lineCount)")

        // Count em dashes (—) in the metrics text
        let emDashCount = metricsText.filter { $0 == "—" }.count
        if emDashCount > 0 {
            analysis.setTextMetric("Em Dashes", "\(emDashCount)")
        }

        // Count common zero-width characters in the metrics text (always recorded, even when 0)
        let zeroWidthScalars: [UnicodeScalar] = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        let zeroWidthSet = CharacterSet(zeroWidthScalars)
        let zwcCount = metricsText.unicodeScalars.filter { zeroWidthSet.contains($0) }.count
        analysis.setTextMetric("Zero-width Characters", "\(zwcCount)")

        // CRLF flag goes in properties, not text metrics (check original text)
        if text.contains("\r") {
            analysis.set("Has CRLF", "Yes")
        }
    }

    private static func isPossiblyURLEncoded(_ text: String) -> Bool {
        guard !text.contains(" ") else { return false }
        if text.contains("+") { return true }
        let pattern = try? NSRegularExpression(pattern: "%[0-9A-Fa-f]{2}", options: [])
        let range = NSRange(text.startIndex..., in: text)
        return (pattern?.firstMatch(in: text, options: [], range: range)) != nil
    }

    private static func parseTimeWithFormat(_ s: String) -> (Date, String)? {
        if let date = TimeFormat.parseEpochSeconds(s) { return (date, "Epoch Seconds") }
        if let date = TimeFormat.parseEpochMilliseconds(s) { return (date, "Epoch Milliseconds") }
        if let date = TimeFormat.parseRFC3339(s) { return (date, "RFC3339 / ISO8601") }
        if let date = TimeFormat.parseSQLDateTime(s) { return (date, "SQL DateTime") }
        if let date = TimeFormat.parseRFC1123(s) { return (date, "RFC1123") }
        if let date = TimeFormat.parseSlashDateTime(s) { return (date, "Slash DateTime") }
        return nil
    }

    private static func isTimestampClaim(_ key: String) -> Bool {
        ["exp", "iat", "nbf", "auth_time"].contains(key)
    }

    private static func dateFromTimestamp(_ number: NSNumber) -> Date? {
        let value = number.doubleValue
        guard value > 0, value < 4102444800 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private static func formatTimestampLocal(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private static func formatTimestampUTC(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private static func isValidBase64Chars(_ s: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+/="))
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func isValidBase64URLChars(_ s: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_="))
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func padBase64(_ s: String) -> String {
        let remainder = s.count % 4
        if remainder == 0 { return s }
        return s + String(repeating: "=", count: 4 - remainder)
    }

    private static func base64URLDecodeToData(_ s: String) -> Data? {
        var base64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 = padBase64(base64)
        return Data(base64Encoded: base64)
    }

    private static func isPrintableString(_ s: String) -> Bool {
        s.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 0x20 && scalar.value < 0x7F ||
            scalar.value == 0x09 || scalar.value == 0x0A || scalar.value == 0x0D ||
            scalar.value > 0x7F
        }
    }

    /// Detects if text looks like prose rather than structured data.
    /// Checks for sentence patterns: period/exclamation/question followed by space and capital letter.
    private static func looksLikeProse(_ s: String) -> Bool {
        let sentencePattern = try? NSRegularExpression(pattern: "[.!?]\\s+[A-Z]", options: [])
        let range = NSRange(s.startIndex..., in: s)
        let matches = sentencePattern?.numberOfMatches(in: s, options: [], range: range) ?? 0
        return matches >= 2
    }

    // MARK: - Fixed-Width Table Helpers

    /// Splits a fixed-width table line into columns using runs of 2+ spaces as delimiters.
    private static func splitFixedWidthLine(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        // Use regex on NSString API to avoid bridging overhead of NSRegularExpression on Swift substrings.
        let nsLine = trimmed as NSString
        let pattern = "\\s{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return trimmed.components(separatedBy: .whitespaces)
        }

        let range = NSRange(location: 0, length: nsLine.length)
        var lastEnd = 0
        var fields: [String] = []

        regex.enumerateMatches(in: trimmed, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            let fieldRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let field = nsLine.substring(with: fieldRange).trimmingCharacters(in: .whitespaces)
            if !field.isEmpty {
                fields.append(field)
            }
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsLine.length {
            let tailRange = NSRange(location: lastEnd, length: nsLine.length - lastEnd)
            let tail = nsLine.substring(with: tailRange).trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty {
                fields.append(tail)
            }
        }

        return fields
    }

    /// Splits a line into columns using any run of 1+ whitespace chars as delimiters.
    /// Used as a fallback for tables that are space-delimited but not strictly aligned with 2+ spaces (e.g. short `ps`).
    private static func splitLooseWhitespaceLine(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    /// Recognizes well-known fixed-width / CLI table types based on header column names.
    private static func recognizeKnownTableType(fromHeaderColumns headerColumns: [String]) -> String? {
        let normalized = headerColumns.map { normalizeHeaderToken($0) }

        let knownPatterns: [(name: String, requiredPrefix: [String])] = [
            ("Docker Containers List", ["CONTAINER ID", "IMAGE", "COMMAND"]),
            ("Docker Images List", ["IMAGE", "ID", "DISK USAGE"]),
            // Order more specific Kubernetes patterns before general ones so they win ties.
            ("Kubernetes Pods List", ["NAME", "READY", "STATUS", "RESTARTS", "AGE"]),
            ("Kubernetes Nodes List", ["NAME", "STATUS", "ROLES"]),
            ("Kubernetes General List", ["NAME", "STATUS", "AGE"]),
            ("Kubernetes Services List", ["NAME", "TYPE", "CLUSTER-IP", "EXTERNAL-IP"]),
            ("Kubernetes Certs List", ["NAME", "READY", "SECRET", "AGE"]),
            ("Process List", ["PID", "CMD"]),
            ("Process List", ["PID", "COMMAND"]),
            ("Netstat", ["PROTO", "RECV-Q", "SEND-Q", "LOCAL ADDRESS", "FOREIGN ADDRESS"]),
            // Open Files List: allow extra columns (e.g. TID/TASKCMD) between PID and USER.
            ("Open Files List", ["COMMAND", "PID", "USER", "FD", "TYPE", "DEVICE", "SIZE/OFF", "NODE NAME"])
        ]

        var bestMatchName: String?
        var bestMatchLength: Int = 0

        for pattern in knownPatterns {
            if headerColumnsMatchInOrder(columns: normalized, requiredSequence: pattern.requiredPrefix),
               pattern.requiredPrefix.count > bestMatchLength {
                bestMatchName = pattern.name
                bestMatchLength = pattern.requiredPrefix.count
            }
        }

        // If we matched a specific known pattern (e.g. Open Files List), prefer that over
        // the more generic Process List heuristics below.
        if let bestMatchName {
            return bestMatchName
        }

        // Generic Process List fallback: if we see PID and either CMD or COMMAND as columns anywhere,
        // treat this as a Process List even if there are additional leading columns like USER
        // or when TIME/COMMAND are merged into a single "TIME COMMAND" header.
        if normalized.contains("PID") {
            let hasCmdLikeHeader = normalized.contains(where: { token in
                token == "CMD" ||
                token == "COMMAND" ||
                token.hasSuffix(" CMD") ||
                token.contains(" CMD ") ||
                token.hasSuffix(" COMMAND") ||
                token.contains(" COMMAND ")
            })
            if hasCmdLikeHeader {
                return "Process List"
            }
        }

        return nil
    }

    private static func normalizeHeaderToken(_ token: String) -> String {
        token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .uppercased()
    }

    /// Returns true when all required header tokens appear in order (not necessarily contiguously).
    /// This makes detection robust to extra columns (e.g. TID/TASKCMD) inserted between known ones.
    private static func headerColumnsMatchInOrder(columns: [String], requiredSequence: [String]) -> Bool {
        guard !requiredSequence.isEmpty else { return false }
        var searchStartIndex = 0

        for required in requiredSequence {
            var found = false
            while searchStartIndex < columns.count {
                if columns[searchStartIndex] == required {
                    found = true
                    searchStartIndex += 1
                    break
                }
                searchStartIndex += 1
            }
            if !found {
                return false
            }
        }

        return true
    }
}

// MARK: - Numeric clipboard analysis (file scope avoids Swift 6 main-actor isolation on nested types)

/// Extensible analysis for ``ClipboardDataType/integer`` and ``ClipboardDataType/decimal``; append steps to the flavor pipelines.
nonisolated private enum ClipboardNumberAnalysis {
    /// Grouping separator for thousands in ``Prettified`` (future: localization hook).
    static let thousandsSeparator = ","

    /// Maximum absolute value shown in numeric analysis rows (omit row when exceeded).
    private static let maxAnalysisMagnitude = Decimal(Int64.max)

    /// Maximum fractional digits after the decimal for ``Flavor/decimal`` display.
    private static let decimalMaxFractionDigits = 15

    enum Flavor {
        case integer
        case decimal
    }

    typealias Step = (inout ClipboardAnalysis, Decimal, String, Flavor) -> Void

    private static let sharedSteps: [Step] = [
        appendSquared,
        appendCubed,
        appendSquareRoot,
        appendCubeRoot,
        appendReciprocal
    ]

    private static let integerPipeline: [Step] = [
        appendPrettifiedIfNeeded,
        appendHexForInteger,
        appendBinaryForInteger
    ] + sharedSteps

    private static let decimalPipeline: [Step] = [
        appendPrettifiedIfNeeded,
        appendFractionalForDecimal
    ] + sharedSteps

    static func apply(to analysis: inout ClipboardAnalysis, value: Decimal, rawInput: String, flavor: Flavor) {
        let pipe = flavor == .integer ? integerPipeline : decimalPipeline
        for step in pipe {
            step(&analysis, value, rawInput, flavor)
        }
    }

    private static let thousandThreshold: Decimal = 1_000

    private static func appendPrettifiedIfNeeded(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        guard decimalAbs(value) > thousandThreshold else { return }
        guard !magnitudeExceedsMaxInt64(value) else { return }
        let display = flavor == .decimal ? applyDecimalFractionalRules(raw) : raw
        analysis.set("Prettified", insertThousandsSeparator(raw: display, sep: thousandsSeparator))
    }

    private static func appendHexForInteger(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        guard flavor == .integer, let i64 = Int64(raw) else { return }
        let hex: String
        if i64 >= 0 {
            hex = String(i64, radix: 16, uppercase: true)
        } else {
            hex = String(UInt64(bitPattern: i64), radix: 16, uppercase: true)
        }
        analysis.set("Hex", "0x\(hex)")
    }

    private static func appendBinaryForInteger(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        guard flavor == .integer, let i64 = Int64(raw) else { return }
        let bin: String
        if i64 >= 0 {
            bin = String(i64, radix: 2)
        } else {
            bin = String(UInt64(bitPattern: i64), radix: 2)
        }
        analysis.set("Binary", bin)
    }

    private static func appendSquared(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        _ = raw
        let r = value * value
        guard let s = formatNumericAnalysisValue(r, flavor: flavor, prettifyForGrouping: true) else { return }
        analysis.set("Squared", s)
    }

    private static func appendCubed(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        _ = raw
        let r = value * value * value
        guard let s = formatNumericAnalysisValue(r, flavor: flavor, prettifyForGrouping: true) else { return }
        analysis.set("Cubed", s)
    }

    private static func appendSquareRoot(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        _ = value
        guard let d = Double(raw), d >= 0, d.isFinite else { return }
        guard let s = formatDoubleForAnalysis(sqrt(d), flavor: flavor, prettifyForGrouping: true) else { return }
        analysis.set("Square Root", s)
    }

    private static func appendCubeRoot(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        _ = value
        guard let d = Double(raw), d.isFinite else { return }
        let r = d >= 0 ? pow(d, 1.0 / 3.0) : -pow(-d, 1.0 / 3.0)
        guard let s = formatDoubleForAnalysis(r, flavor: flavor, prettifyForGrouping: true) else { return }
        analysis.set("Cube Root", s)
    }

    private static func appendReciprocal(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        _ = (raw, flavor)
        guard value != 0 else { return }
        let one: Decimal = 1
        let inv = one / value
        // Reciprocal is almost always non-integer; use decimal fractional rules regardless of clipboard ``Flavor``.
        guard let s = formatNumericAnalysisValue(inv, flavor: .decimal, prettifyForGrouping: false) else { return }
        analysis.set("Reciprocal", s)
    }

    private static func appendFractionalForDecimal(_ analysis: inout ClipboardAnalysis, value: Decimal, raw: String, flavor: Flavor) {
        guard flavor == .decimal, let d = Double(raw), d.isFinite else { return }
        guard !magnitudeExceedsMaxInt64(d) else { return }
        let mag = abs(d)
        let ip = floor(mag)
        let frac = mag - ip
        let tolerance = 1e-6
        guard frac > tolerance, frac < 1 - tolerance else { return }
        guard let (num, den) = approximateSimpleFraction(frac, maxDenominator: 16, tolerance: tolerance) else { return }
        guard let intStr = formatDoubleForAnalysis(ip, flavor: .decimal, prettifyForGrouping: false) else { return }
        let body = "\(intStr) + \(num)/\(den)"
        analysis.set("Fractional", d < 0 ? "-(\(body))" : body)
    }

    // MARK: - Magnitude / formatting

    private static func magnitudeExceedsMaxInt64(_ x: Decimal) -> Bool {
        decimalAbs(x) > maxAnalysisMagnitude
    }

    private static func magnitudeExceedsMaxInt64(_ x: Double) -> Bool {
        guard x.isFinite else { return true }
        return decimalAbs(Decimal(x)) > maxAnalysisMagnitude
    }

    /// Formats a ``Decimal`` result for analysis; returns `nil` when ``magnitudeExceedsMaxInt64``.
    private static func formatNumericAnalysisValue(_ x: Decimal, flavor: Flavor, prettifyForGrouping: Bool) -> String? {
        guard !magnitudeExceedsMaxInt64(x) else { return nil }
        var plain = formatDecimalPlain(x)
        if plain.contains("e") || plain.contains("E") {
            if let normalized = normalizeScientificDecimalString(plain) {
                plain = normalized
            }
        }
        if flavor == .decimal {
            plain = applyDecimalFractionalRules(plain)
        }
        if prettifyForGrouping && decimalAbs(x) >= thousandThreshold {
            return insertThousandsSeparator(raw: plain, sep: thousandsSeparator)
        }
        return plain
    }

    private static func formatDoubleForAnalysis(_ x: Double, flavor: Flavor, prettifyForGrouping: Bool) -> String? {
        guard x.isFinite else { return nil }
        guard !magnitudeExceedsMaxInt64(x) else { return nil }
        let trimmed = formatDoubleTrimmed(x)
        guard let dec = Decimal(string: trimmed) else {
            return formatNumericAnalysisValue(Decimal(x), flavor: flavor, prettifyForGrouping: prettifyForGrouping)
        }
        return formatNumericAnalysisValue(dec, flavor: flavor, prettifyForGrouping: prettifyForGrouping)
    }

    /// Decimal clipboard values: cap fractional length at ``decimalMaxFractionDigits``, and keep from the start of the fraction through (first non-zero + next 4 digits), e.g. `2388.000000000200123…` → `2388.00000000020012`.
    private static func applyDecimalFractionalRules(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard t.contains(".") else { return t }
        let negative = t.hasPrefix("-")
        let unsigned = negative ? String(t.dropFirst()) : t
        guard let udot = unsigned.firstIndex(of: ".") else { return t }
        let intPart = String(unsigned[..<udot])
        var frac = String(unsigned[unsigned.index(after: udot)...])
        frac = String(frac.prefix { $0.isNumber })
        guard let firstNonZero = frac.firstIndex(where: { $0 != "0" }) else {
            return (negative ? "-" : "") + intPart
        }
        let lead = frac.distance(from: frac.startIndex, to: firstNonZero)
        let fracEndLen = min(lead + 5, decimalMaxFractionDigits, frac.count)
        let clipped = String(frac.prefix(fracEndLen))
        return (negative ? "-" : "") + intPart + "." + clipped
    }

    private static func normalizeScientificDecimalString(_ s: String) -> String? {
        guard let d = Double(s), d.isFinite else { return nil }
        guard !magnitudeExceedsMaxInt64(d) else { return nil }
        return formatDecimalPlain(Decimal(d))
    }

    private static func approximateSimpleFraction(_ f: Double, maxDenominator: Int, tolerance: Double) -> (Int, Int)? {
        var best: (Int, Int)?
        var bestErr = Double.greatestFiniteMagnitude
        for den in 1...maxDenominator {
            let num = Int((f * Double(den)).rounded())
            guard num >= 1, num < den else { continue }
            let err = abs(f - Double(num) / Double(den))
            if err < bestErr {
                bestErr = err
                best = (num, den)
            }
        }
        guard let b = best, bestErr <= tolerance else { return nil }
        let g = greatestCommonDivisor(b.0, b.1)
        return (b.0 / g, b.1 / g)
    }

    private static func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var a = abs(a)
        var b = abs(b)
        while b != 0 {
            let t = a % b
            a = b
            b = t
        }
        return max(a, 1)
    }

    private static func decimalAbs(_ x: Decimal) -> Decimal {
        x < 0 ? -x : x
    }

    private static func insertThousandsSeparator(raw: String, sep: String) -> String {
        if raw.contains(".") {
            let parts = raw.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let intPart = String(parts[0])
            let frac = parts.count > 1 ? String(parts[1]) : ""
            let neg = intPart.hasPrefix("-")
            let digits = neg ? String(intPart.dropFirst()) : intPart
            guard digits.allSatisfy(\.isNumber) else { return raw }
            let core = groupDigits(digits, sep: sep)
            let signed = neg ? "-" + core : core
            return frac.isEmpty ? signed : "\(signed).\(frac)"
        }
        let neg = raw.hasPrefix("-")
        let digits = neg ? String(raw.dropFirst()) : raw
        guard digits.allSatisfy(\.isNumber) else { return raw }
        let core = groupDigits(digits, sep: sep)
        return neg ? "-" + core : core
    }

    private static func groupDigits(_ integralDigits: String, sep: String) -> String {
        let chars = Array(integralDigits)
        var parts: [String] = []
        var i = chars.count
        while i > 0 {
            let start = max(0, i - 3)
            parts.append(String(chars[start..<i]))
            i = start
        }
        return parts.reversed().joined(separator: sep)
    }

    private static func formatDecimalPlain(_ x: Decimal) -> String {
        var d = x
        return NSDecimalString(&d, Locale(identifier: "en_US_POSIX") as NSLocale?)
    }

    private static func formatDoubleTrimmed(_ x: Double) -> String {
        guard x.isFinite else { return "\(x)" }
        return String(format: "%.15g", x)
    }
}
