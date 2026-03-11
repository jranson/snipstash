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
    case databaseCLITable = "Database CLI Table"
    case generalText = "General Text"
}

/// Result of clipboard analysis with type-safe access to detected properties.
/// Uses ordered array to preserve insertion order for display.
struct ClipboardAnalysis {
    /// Marker key for divider in displayItems
    static let dividerKey = "---"

    let dataType: ClipboardDataType
    private var orderedProperties: [(key: String, value: String)] = []
    private var textMetrics: [(key: String, value: String)] = []

    init(dataType: ClipboardDataType) {
        self.dataType = dataType
    }

    /// All analysis key-value pairs for display, including dataType.
    /// Text metrics (Characters, Words, Lines, Em Dashes) are always last, preceded by a divider marker.
    var displayItems: [(key: String, value: String)] {
        var items: [(String, String)] = [("Data Type", dataType.rawValue)]
        items.append(contentsOf: orderedProperties)
        if !textMetrics.isEmpty {
            items.append((Self.dividerKey, ""))
            items.append(contentsOf: textMetrics)
        }
        return items
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

    /// Convenience accessor for database CLI format (e.g., "MySQL CLI", "psql", "sqlite3").
    var databaseFormat: String? {
        self["Format"]
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

}

/// Clipboard content analyzer for type detection and type-specific analysis.
enum ClipboardAnalyzer {

    /// Analyze clipboard text content and return structured analysis.
    /// Returns nil if input is nil (non-text clipboard).
    static func analyze(_ text: String?) -> ClipboardAnalysis {
        guard let text = text else {
            return ClipboardAnalysis(dataType: .nonText)
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return analyzeGeneralText(text)
        }

        if let analysis = detectJWT(trimmed, original: text) { return analysis }
        if let analysis = detectURL(trimmed, original: text) { return analysis }
        if let analysis = detectTime(trimmed, original: text) { return analysis }
        if let analysis = detectBase64URL(trimmed, original: text) { return analysis }
        if let analysis = detectBase64(trimmed, original: text) { return analysis }
        if let analysis = detectJSON(trimmed, original: text) { return analysis }
        if let analysis = detectDatabaseCLITable(trimmed, original: text) { return analysis }
        if let analysis = detectCSV(trimmed, original: text) { return analysis }
        if let analysis = detectTSV(trimmed, original: text) { return analysis }
        if let analysis = detectPSV(trimmed, original: text) { return analysis }
        if let analysis = detectYAML(trimmed, original: text) { return analysis }

        return analyzeGeneralText(text)
    }

    // MARK: - Type Detection

    private static func detectJWT(_ trimmed: String, original: String) -> ClipboardAnalysis? {
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

        if let payloadData = base64URLDecodeToData(payloadPart),
           let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            for (key, value) in payloadJSON.sorted(by: { $0.key < $1.key }) {
                let displayKey = "Payload: \(key)"
                if let stringValue = value as? String {
                    analysis.set(displayKey, stringValue)
                } else if let numValue = value as? NSNumber {
                    if isTimestampClaim(key), let date = dateFromTimestamp(numValue) {
                        analysis.set(displayKey, formatTimestampLocal(date))
                    } else {
                        analysis.set(displayKey, "\(numValue)")
                    }
                } else if let boolValue = value as? Bool {
                    analysis.set(displayKey, boolValue ? "true" : "false")
                } else if let arrayValue = value as? [Any] {
                    let items = arrayValue.compactMap { item -> String? in
                        if let s = item as? String { return s }
                        if let n = item as? NSNumber { return "\(n)" }
                        return nil
                    }
                    analysis.set(displayKey, items.joined(separator: ", "))
                } else {
                    analysis.set(displayKey, String(describing: value))
                }
            }
        }

        return analysis
    }

    private static func detectURL(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else { return nil }
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: firstLine), url.host != nil else { return nil }

        var analysis = ClipboardAnalysis(dataType: .url)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Scheme", url.scheme ?? "")
        if let user = url.user, !user.isEmpty {
            analysis.set("Username", user)
            if let password = url.password, !password.isEmpty {
                analysis.set("Password", "••••••••")
            }
        }
        if let host = url.host {
            analysis.set("Host", host)
        }
        if let port = url.port {
            analysis.set("Port", "\(port)")
        }
        if !url.path.isEmpty && url.path != "/" {
            analysis.set("Path", url.path)
        }
        if let query = url.query, !query.isEmpty {
            analysis.set("Query Params", "\(query.components(separatedBy: "&").count)")
        }
        if let fragment = url.fragment, !fragment.isEmpty {
            analysis.set("Fragment", fragment)
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

    private static func detectBase64URL(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard trimmed.count >= 4,
              !trimmed.contains("+"),
              !trimmed.contains("/"),
              (trimmed.contains("-") || trimmed.contains("_")),
              isValidBase64URLChars(trimmed) else { return nil }

        guard let decoded = base64URLDecodeToData(trimmed),
              decoded.count >= 1,
              let decodedString = String(data: decoded, encoding: .utf8),
              isPrintableString(decodedString) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .base64URL)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Decoded Length", "\(decoded.count) bytes")
        let preview = decodedString.prefix(32)
        analysis.set("Decoded Preview", String(preview) + (decodedString.count > 32 ? "…" : ""))

        return analysis
    }

    private static func detectBase64(_ trimmed: String, original: String) -> ClipboardAnalysis? {
        guard trimmed.count >= 4,
              isValidBase64Chars(trimmed) else { return nil }

        let paddedInput = padBase64(trimmed)
        guard let decoded = Data(base64Encoded: paddedInput),
              decoded.count >= 1,
              let decodedString = String(data: decoded, encoding: .utf8),
              isPrintableString(decodedString) else { return nil }

        var analysis = ClipboardAnalysis(dataType: .base64)
        addTextMetrics(to: &analysis, text: original)
        analysis.set("Decoded Length", "\(decoded.count) bytes")
        let preview = decodedString.prefix(32)
        analysis.set("Decoded Preview", String(preview) + (decodedString.count > 32 ? "…" : ""))

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
        if let analysis = detectPsqlTable(lines, original: original) { return analysis }
        if let analysis = detectSqlite3Table(lines, original: original) { return analysis }

        return nil
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
        // Reject if text looks like prose
        if looksLikeProse(trimmed) { return nil }

        let lines = trimmed.components(separatedBy: .newlines)

        // Count YAML-like lines vs total non-empty lines
        var yamlLikeLines = 0
        var nonEmptyLines = 0
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            nonEmptyLines += 1

            // YAML array item: starts with "- " and the rest is short (not a sentence)
            if t.hasPrefix("- ") {
                let rest = String(t.dropFirst(2))
                if rest.count < 80 && !rest.contains(". ") {
                    yamlLikeLines += 1
                    continue
                }
            }

            // YAML key-value: contains ": " where key is a simple identifier
            if let colonRange = t.range(of: ": ") {
                let key = String(t[..<colonRange.lowerBound])
                // Key should be simple: no spaces (unless quoted), not starting with http
                let isSimpleKey = !key.contains(" ") || (key.hasPrefix("\"") && key.hasSuffix("\"")) || (key.hasPrefix("'") && key.hasSuffix("'"))
                if isSimpleKey && !key.hasPrefix("http") {
                    yamlLikeLines += 1
                    continue
                }
            }
        }

        // Require significant YAML structure (at least 50% of lines look like YAML)
        guard nonEmptyLines >= 2 && yamlLikeLines * 2 >= nonEmptyLines else { return nil }

        let hasJsonStart = trimmed.hasPrefix("{") || trimmed.hasPrefix("[")
        guard !hasJsonStart else { return nil }

        var analysis = ClipboardAnalysis(dataType: .yaml)
        addTextMetrics(to: &analysis, text: original)

        // Detect minification: single line after trimming means minified (rare for YAML but possible)
        let lineCount = trimmed.components(separatedBy: .newlines).count
        analysis.set("Minified", lineCount == 1 ? "Yes" : "No")

        let isArrayStyle = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }?.trimmingCharacters(in: .whitespaces).hasPrefix("-") ?? false
        analysis.set("Structure", isArrayStyle ? "Array" : "Object")

        return analysis
    }

    private static func analyzeGeneralText(_ text: String) -> ClipboardAnalysis {
        var analysis = ClipboardAnalysis(dataType: .generalText)
        addTextMetrics(to: &analysis, text: text)
        return analysis
    }

    // MARK: - Helpers

    private static func addTextMetrics(to analysis: inout ClipboardAnalysis, text: String) {
        // Text metrics go in a separate section at the bottom
        analysis.setTextMetric("Characters", "\(text.count)")
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        analysis.setTextMetric("Words", "\(words.count)")
        let lines = text.components(separatedBy: .newlines)
        let lineCount = text.hasSuffix("\n") ? lines.count : max(1, lines.count)
        analysis.setTextMetric("Lines", "\(lineCount)")

        // Count em dashes (—)
        let emDashCount = text.filter { $0 == "—" }.count
        if emDashCount > 0 {
            analysis.setTextMetric("Em Dashes", "\(emDashCount)")
        }

        // CRLF flag goes in properties, not text metrics
        if text.contains("\r") {
            analysis.set("Has CRLF", "Yes")
        }
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
}
