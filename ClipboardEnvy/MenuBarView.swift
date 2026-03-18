import SwiftUI
import SwiftData
import AppKit

@MainActor
struct MenuBarView: View {
    private static let recentSnippetsMenuCountRange: ClosedRange<Int> = 0...20
    @AppStorage("recentSnippetsMenuCount") private var recentSnippetsMenuCount = 10
    private static let snippetMenuLabelMaxCharsRange: ClosedRange<Int> = 10...64
    @AppStorage("snippetMenuLabelMaxChars") private var snippetMenuLabelMaxChars = 36

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false
    @AppStorage("demoMenuEnabled") private var demoMenuEnabled = false

    @State private var clipboardAnalysis = ClipboardAnalysis(dataType: .nonText)
    @State private var shouldShowAll = false

    private var snippets: [Snippet] { snippetsStore.snippets }

    // MARK: - Sparkle helpers

    private func appendSparkleIf(_ base: String, condition: Bool) -> String {
        condition ? "\(base) ✨" : base
    }

    // MARK: - Menu Visibility Computed Properties

    private var showTimeMenu: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .time
    }

    private var timeMenuLabel: String {
        appendSparkleIf("Time", condition: !shouldShowAll && clipboardAnalysis.dataType == .time)
    }

    private var showJWTDecode: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .jwt
    }

    private var showBase64Decode: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .base64
    }

    private var showBase64URLDecode: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .base64URL
    }

    // MARK: - Sparkle Decorators (for context-aware suggestions)

    private var isUrlWithParams: Bool {
        clipboardAnalysis.dataType == .url && clipboardAnalysis.urlHasQuery
    }

    private var hasCarriageReturns: Bool {
        clipboardAnalysis.hasCarriageReturns
    }

    private var hasZeroWidthCharacters: Bool {
        clipboardAnalysis.zeroWidthCharacterCount > 0
    }

    private var isJsonArray: Bool {
        clipboardAnalysis.dataType == .json && clipboardAnalysis.isArrayStructure
    }

    /// True when the JSON array is a simple list of literals (strings / numbers / booleans / null),
    /// e.g. ["Commas", "Spaces", "Tabs"]. Backed by JSON helpers rather than the view.
    private var isSimpleLiteralJsonArray: Bool {
        guard clipboardAnalysis.dataType == .json,
              clipboardAnalysis.isArrayStructure,
              let text = ClipboardIO.readString() else {
            return false
        }
        return ClipboardTransform.isSimpleLiteralJsonArray(text)
    }

    private var showQuickAction: Bool {
        [.jwt, .base64, .base64URL].contains(clipboardAnalysis.dataType)
            || isUrlWithParams
            || hasCarriageReturns
            // Only treat JSON arrays as a quick action source when they are
            // not simple literal lists; those should be hidden unless Option is held.
            || (isJsonArray && !isSimpleLiteralJsonArray)
            || hasZeroWidthCharacters
    }

    private var isPossiblyURLEncoded: Bool {
        clipboardAnalysis.isPossiblyURLEncoded
    }

    private var showURLDecode: Bool {
        shouldShowAll || isPossiblyURLEncoded
    }

    // MARK: - Encode & Hash Menu

    private var encodeHashMenuLabel: String {
        appendSparkleIf(
            "Encode / Hash",
            condition: !shouldShowAll && (
                clipboardAnalysis.dataType == .jwt ||
                clipboardAnalysis.dataType == .base64 ||
                clipboardAnalysis.dataType == .base64URL ||
                isPossiblyURLEncoded
            )
        )
    }

    // MARK: - URLs Menu

    private var isURL: Bool {
        clipboardAnalysis.dataType == .url
    }

    private var urlsMenuLabel: String {
        appendSparkleIf("URLs", condition: !shouldShowAll && isURL)
    }

    private var showURLExtractSection: Bool {
        shouldShowAll || isURL
    }

    private var showURLExtractHostPort: Bool {
        shouldShowAll || clipboardAnalysis.urlHasPort
    }

    private var showURLExtractPort: Bool {
        shouldShowAll || clipboardAnalysis.urlHasPort
    }

    private var showURLExtractUsername: Bool {
        shouldShowAll || clipboardAnalysis.urlHasUsername
    }

    private var showURLExtractCredentials: Bool {
        shouldShowAll || (clipboardAnalysis.urlHasUsername && clipboardAnalysis.urlHasPassword)
    }

    private var showURLExtractPath: Bool {
        shouldShowAll || clipboardAnalysis.urlHasPath
    }

    private var showURLExtractQuery: Bool {
        shouldShowAll || clipboardAnalysis.urlHasQuery
    }

    private var showURLExtractFragment: Bool {
        shouldShowAll || clipboardAnalysis.urlHasFragment
    }

    private var showJSONYAMLMenu: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .json || clipboardAnalysis.dataType == .yaml
    }

    private var showJSONYAMLPrettify: Bool {
        shouldShowAll || clipboardAnalysis.isMinified
    }

    private var showJSONYAMLMinify: Bool {
        shouldShowAll || !clipboardAnalysis.isMinified
    }

    private var showJSONArrayToCsv: Bool {
        // When showing all items (Option held), always offer Array → CSV for arrays.
        if shouldShowAll {
            return clipboardAnalysis.isArrayStructure
        }
        // For normal mode, hide CSV transforms for simple literal arrays like
        // ["Commas", "Spaces", ...].
        if isSimpleLiteralJsonArray {
            return false
        }
        return clipboardAnalysis.isArrayStructure
    }

    private var jsonYAMLMenuLabel: String {
        if shouldShowAll { return "JSON / YAML" }
        switch clipboardAnalysis.dataType {
        case .json: return appendSparkleIf("JSON", condition: true)
        case .yaml: return appendSparkleIf("YAML", condition: true)
        default: return "JSON / YAML"
        }
    }

    private var showJSONSection: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .json
    }

    private var showYAMLSection: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .yaml
    }

    private var showCSVMenu: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .csv || clipboardAnalysis.dataType == .tsv || clipboardAnalysis.dataType == .psv || clipboardAnalysis.dataType == .fixedWidthTable
    }

    private var csvMenuLabel: String {
        if shouldShowAll { return "CSV" }
        switch clipboardAnalysis.dataType {
        case .fixedWidthTable:
            if let tableName = clipboardAnalysis.tableTypeName {
                return appendSparkleIf(tableName, condition: true)
            }
            return appendSparkleIf("Table", condition: true)
        case .csv: return appendSparkleIf("CSV", condition: true)
        case .tsv: return appendSparkleIf("TSV", condition: true)
        case .psv: return appendSparkleIf("PSV", condition: true)
        default: return "CSV"
        }
    }

    private var showCSVSection: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .csv
    }

    private var showTSVPSVSection: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .tsv || clipboardAnalysis.dataType == .psv
    }

    private var showTSVToCsv: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .tsv
    }

    private var showPSVToCsv: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .psv
    }

    private var showMultilineMenu: Bool {
        shouldShowAll || clipboardAnalysis.lineCount > 1
    }

    private var generalTextMenuLabel: String {
        appendSparkleIf("General Text", condition: isSimpleLiteralJsonArray || hasZeroWidthCharacters)
    }

    // MARK: - Column Menu Properties

    @State private var csvColumnHeaders: [String] = []

    private var showColumnsSection: Bool {
        clipboardAnalysis.isDelimitedData && !csvColumnHeaders.isEmpty
    }

    private var showDatabaseCLIMenu: Bool {
        shouldShowAll || clipboardAnalysis.dataType == .databaseCLITable
    }

    private var databaseCLIMenuLabel: String {
        appendSparkleIf(
            "Database CLI",
            condition: !shouldShowAll && clipboardAnalysis.dataType == .databaseCLITable
        )
    }

    private var showMySQLSection: Bool {
        shouldShowAll || clipboardAnalysis.databaseFormat == "MySQL CLI"
    }

    private var showPsqlSection: Bool {
        shouldShowAll || clipboardAnalysis.databaseFormat == "psql"
    }

    private var showSqlite3Section: Bool {
        shouldShowAll || clipboardAnalysis.databaseFormat == "sqlite3"
    }

    // Time format visibility - hide transform to same format
    private var showEpochSecondsTransform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "Epoch Seconds"
    }

    private var showEpochMillisecondsTransform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "Epoch Milliseconds"
    }

    private var showSQLDateTimeTransform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "SQL DateTime"
    }

    private var showRFC3339Transform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "RFC3339 / ISO8601"
    }

    private var showRFC1123Transform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "RFC1123"
    }

    private var showSlashDateTimeTransform: Bool {
        shouldShowAll || clipboardAnalysis.timeFormat != "Slash DateTime"
    }

    /// When true in Debug builds, show demo snippets for screenshots.
    private var useDemoSnippets: Bool {
        #if DEBUG
        return demoMenuEnabled
        #else
        return false
        #endif
    }

    private var displayedSnippets: [Snippet] {
        #if DEBUG
        if useDemoSnippets { return Self.demoSnippets }
        #endif
        return snippets
    }

    private var recentDisplayedSnippets: [Snippet] {
        let limit = min(
            max(recentSnippetsMenuCount, Self.recentSnippetsMenuCountRange.lowerBound),
            Self.recentSnippetsMenuCountRange.upperBound
        )

        // Pick the most-recently modified snippets by timestamp,
        // but preserve the existing menu ordering (so Move Up/Down semantics match).
        let recentIDs = Set(
            displayedSnippets
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(limit)
                .map(\.id)
        )
        return displayedSnippets.filter { recentIDs.contains($0.id) }
    }

    #if DEBUG
    /// Demo snippets for App Store screenshots.
    private static let demoSnippets: [Snippet] = {
        let t0 = Date(timeIntervalSince1970: 0)
        return [
            Snippet(body: "https://google.com", title: "Track 1ZN018AKFUPAIH", timestamp: Date(timeInterval: 1, since: t0)),
            Snippet(body: "Jump Server FQDN", title: nil, timestamp: Date(timeInterval: 3, since: t0)),
            Snippet(body: "John's PubKey", title: nil, timestamp: Date(timeInterval: 4, since: t0)),
            Snippet(body: "Interview ?s Markdown: AWS Lambda", title: nil, timestamp: Date(timeInterval: 5, since: t0)),
            Snippet(body: "https://github.com/org/repo/issues", title: nil, timestamp: Date(timeInterval: 6, since: t0)),
        ]
    }()
    #endif

    var body: some View {
        Menu("Clipboard Data Analysis") {
            ForEach(Array(clipboardAnalysis.displayItems.enumerated()), id: \.offset) { _, item in
                if item.key == ClipboardAnalysis.dividerKey {
                    Divider()
                } else {
                    Text("\(item.key): \(item.value)")
                }
            }
            if showQuickAction {
                Divider()
            }
            if clipboardAnalysis.dataType == .jwt {
                Button("Decode JWT Payload ✨") { transformClipboardIfValid(ClipboardTransform.jwtDecode) }
            }
            if clipboardAnalysis.dataType == .base64 {
                Button("Decode Base64 ✨") { transformClipboard(ClipboardTransform.base64Decode) }
            }
            if clipboardAnalysis.dataType == .base64URL {
                Button("Decode Base64 ✨") { transformClipboard(ClipboardTransform.base64URLDecode) }
            }
            if isUrlWithParams {
                Button("Strip URL Params ✨") { transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid) }
            }
            if hasCarriageReturns {
                Button("CRLF → LF (strip \\r) ✨") { transformClipboard(ClipboardTransform.windowsNewlinesToUnix) }
            }
            if hasZeroWidthCharacters {
                Button(appendSparkleIf("Strip Zero-width Chars", condition: hasZeroWidthCharacters)) {
                    transformClipboard(ClipboardTransform.removeZeroWidthCharacters)
                }
            }
            if isJsonArray && (!isSimpleLiteralJsonArray || shouldShowAll) {
                Button("JSON Array → CSV ✨") { transformClipboardIfValid(ClipboardTransform.jsonArrayToCsv) }
            }
            if isSimpleLiteralJsonArray {
                Button("Split JSON Array ✨") {
                    transformClipboardIfValid { input in
                        ClipboardTransform.simpleLiteralJsonArrayToLines(input) ?? input
                    }
                }
            }
        }
        if clipboardAnalysis.dataType != .nonText {
            Menu("Transform Clipboard Text") {
            Menu(generalTextMenuLabel) {
                if isSimpleLiteralJsonArray {
                    Button("Split JSON Array ✨") {
                        transformClipboardIfValid { input in
                            ClipboardTransform.simpleLiteralJsonArrayToLines(input) ?? input
                        }
                    }
                    Divider()
                }
                Menu("Casing") {
                    Button("UPPERCASE") { transformClipboard(ClipboardTransform.uppercase) }
                    Button("lowercase") { transformClipboard(ClipboardTransform.lowercase) }
                    Button("Trimmed") { transformClipboard(ClipboardTransform.trimmed) }
                    Button("trim+lowercase") { transformClipboard(ClipboardTransform.lowercaseTrimmed) }
                    Divider()
                    Button("Title Case") { transformClipboard(ClipboardTransform.titleCase) }
                    Button("Sentence case") { transformClipboard(ClipboardTransform.sentenceCase) }
                    Divider()
                    Button("camelCase") { transformClipboard(ClipboardTransform.camelCase) }
                    Button("PascalCase") { transformClipboard(ClipboardTransform.pascalCase) }
                    Button("kebab-slug-case") { transformClipboard(ClipboardTransform.slugify) }
                    Button("snake_case") { transformClipboard(ClipboardTransform.snakeCase) }
                    Button("CONST_CASE") { transformClipboard(ClipboardTransform.constCase) }
                }
                Menu(appendSparkleIf("Remove", condition: hasZeroWidthCharacters)) {
                    Button("Single Quotes") {
                        transformClipboard { ClipboardTransform.removeSubstring($0, target: "'") }
                    }
                    Button("Double Quotes") {
                        transformClipboard { ClipboardTransform.removeSubstring($0, target: "\"") }
                    }
                    Button("Commas") {
                        transformClipboard { ClipboardTransform.removeSubstring($0, target: ",") }
                    }
                    Button("Spaces") {
                        transformClipboard { ClipboardTransform.removeSubstring($0, target: " ") }
                    }
                    if (shouldShowAll || hasZeroWidthCharacters) {
                        Button(appendSparkleIf("Zero-width Chars", condition: hasZeroWidthCharacters)) {
                            transformClipboard(ClipboardTransform.removeZeroWidthCharacters)
                        }
                    }
                    let customRemoves = ClipboardTransform.customMultilineRemoves()
                    if !customRemoves.isEmpty {
                        Divider()
                        ForEach(customRemoves, id: \.label) { item in
                            Button(item.label) {
                                transformClipboard {
                                    ClipboardTransform.removeSubstring($0, target: item.target)
                                }
                            }
                        }
                    }
                }
                Menu("Replace") {
                    Button("Single → Double Quotes") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "'", to: "\"")
                        }
                    }
                    Button("Double → Single Quotes") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "\"", to: "'")
                        }
                    }
                    Button("Fancy → Straight Quotes") {
                        transformClipboard(ClipboardTransform.fancyQuotesToStraight)
                    }
                    Button("2 Spaces → Tab") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "  ", to: "\t")
                        }
                    }
                    Button("4 Spaces → Tab") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "    ", to: "\t")
                        }
                    }
                    Button("Tab → 2 Spaces") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "\t", to: "  ")
                        }
                    }
                    Button("Tab → 4 Spaces") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "\t", to: "    ")
                        }
                    }
                    Button("CommaSpace → Comma") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: ", ", to: ",")
                        }
                    }
                    Button("Comma → CommaSpace") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: ",", to: ", ")
                        }
                    }
                    Button("Backslash → Slash") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "\\", to: "/")
                        }
                    }
                    Button("Slash → Backslash") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "/", to: "\\")
                        }
                    }
                    Button("//  →  #") {
                        transformClipboard {
                            ClipboardTransform.swapSubstrings($0, from: "//", to: "#")
                        }
                    }
                    let customSwaps = ClipboardTransform.customMultilineSwaps()
                    if !customSwaps.isEmpty {
                        Divider()
                        ForEach(customSwaps, id: \.label) { item in
                            Button(item.label) {
                                transformClipboard {
                                    ClipboardTransform.swapSubstrings($0, from: item.from, to: item.to)
                                }
                            }
                        }
                    }
                }
                Menu("Split to Lines") {
                    Section("Split On") {
                        ForEach(ClipboardTransform.builtinMultilineJoiners(), id: \.label) { item in
                            Button(item.label) {
                                transformClipboard {
                                    ClipboardTransform.splitLines(on: item.delimiter, $0)
                                }
                            }
                        }
                        let custom = ClipboardTransform.customMultilineJoiners()
                        if !custom.isEmpty {
                            Divider()
                            ForEach(custom, id: \.label) { item in
                                Button(item.label) {
                                    transformClipboard {
                                        ClipboardTransform.splitLines(on: item.delimiter, $0)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if showTimeMenu {
                Menu(timeMenuLabel) {
                    if showEpochSecondsTransform {
                        Button("→ Epoch (s)") { transformClipboardIfValid(ClipboardTransform.timeToEpochSeconds) }
                    }
                    if showEpochMillisecondsTransform {
                        Button("→ Epoch (ms)") { transformClipboardIfValid(ClipboardTransform.timeToEpochMilliseconds) }
                    }
                    if showSQLDateTimeTransform {
                        Divider()
                        Button("→ SQL DateTime (Local)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeLocal) }
                        Button("→ SQL DateTime (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeUTC) }
                    }
                    if showRFC3339Transform {
                        Divider()
                        Button("→ RFC3339 (Z)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339Z) }
                        Button("→ RFC3339 (+offset)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithOffset) }
                        Button("→ RFC3339 (tz abbrev)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithAbbreviation) }
                    }
                    if showRFC1123Transform {
                        Divider()
                        Button("→ RFC1123 (Local)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123Local) }
                        Button("→ RFC1123 (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123UTC) }
                    }
                    if showSlashDateTimeTransform {
                        Divider()
                        Button("→ YYYY/MM/DD hh:mm:ss (Local)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDHHmmssLocal) }
                        Button("→ YYYY/MM/DD hh:mm:ss (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDHHmmssUTC) }
                        Button("→ YY/MM/DD hh:mm:ss (Local)") { transformClipboardIfValid(ClipboardTransform.timeToYYMMDDHHmmssLocal) }
                        Button("→ YY/MM/DD hh:mm:ss (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToYYMMDDHHmmssUTC) }
                        Divider()
                        Button("→ YYYY/MM/DD (Local)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDLocal) }
                        Button("→ YYYY/MM/DD (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDUTC) }
                        Button("→ YYYY/MM/DD/HH (Local)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDHHLocal) }
                        Button("→ YYYY/MM/DD/HH (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToYYYYMMDDHHUTC) }
                        Button("→ YY/MM/DD (Local)") { transformClipboardIfValid(ClipboardTransform.timeToYYMMDDLocal) }
                        Button("→ YY/MM/DD (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToYYMMDDUTC) }
                    }
                }
            }
            if showURLExtractSection {
                Menu(urlsMenuLabel) {
                    Section("Extract") {
                        Button("Host (Domain)") { transformClipboardIfValid(ClipboardTransform.urlExtractHostIfValid) }
                        if showURLExtractHostPort {
                            Button("Host:Port") { transformClipboardIfValid(ClipboardTransform.urlExtractHostPortIfValid) }
                        }
                        if showURLExtractPort {
                            Button("Port") { transformClipboardIfValid(ClipboardTransform.urlExtractPortIfValid) }
                        }
                        if showURLExtractPath {
                            Button("Path") { transformClipboardIfValid(ClipboardTransform.urlExtractPathIfValid) }
                        }
                        if showURLExtractQuery {
                            Button("Params") { transformClipboardIfValid(ClipboardTransform.urlExtractQueryIfValid) }
                        }
                        if showURLExtractFragment {
                            Button("Hash") { transformClipboardIfValid(ClipboardTransform.urlExtractFragmentIfValid) }
                        }
                        if showURLExtractUsername {
                            Button("Username") { transformClipboardIfValid(ClipboardTransform.urlExtractUsernameIfValid) }
                        }
                        if showURLExtractCredentials {
                            Button("Username:Password") { transformClipboardIfValid(ClipboardTransform.urlExtractCredentialsIfValid) }
                        }
                    }
                    if showURLExtractSection && (showURLExtractUsername || showURLExtractQuery) {
                        Divider()
                    }
                    if showURLExtractUsername {
                        Button(showURLExtractCredentials ? "Strip user:pass" : "Strip user") {
                            transformClipboardIfValid(ClipboardTransform.urlStripCredentialsIfValid)
                        }
                    }
                    if showURLExtractQuery {
                        Button(isUrlWithParams && !shouldShowAll ? "Strip URL Params ✨" : "Strip URL Params") {
                            transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid)
                        }
                    }
                }
            }

            Menu("Multi-line") {
                if clipboardAnalysis.lineCount > 1 || shouldShowAll {
                    Menu("Sort Lines") {
                        Button("Reverse Order") { transformClipboard(ClipboardTransform.reverseLines) }
                        Button("Alphabetically") { transformClipboard(ClipboardTransform.sortLines) }
                        Button("By Frequency ↑") { transformClipboard(ClipboardTransform.sortLinesByFrequencyAscending) }
                        Button("By Frequency ↓") { transformClipboard(ClipboardTransform.sortLinesByFrequencyDescending) }
                        Button("Shuffle") { transformClipboard(ClipboardTransform.shuffleLines) }
                    }
                    Divider()
                    Menu("Collapse Lines") {
                        Button("Deduplicate") { transformClipboard(ClipboardTransform.deduplicateLines) }
                        Button("Dedupe + Alpha Sort") { transformClipboard(ClipboardTransform.sortAndDeduplicateLines) }
                        Button("Drop Empty") { transformClipboard(ClipboardTransform.removeEmptyLines) }
                        Button("Drop Unique") { transformClipboard(ClipboardTransform.removeUniqueLines) }
                        Button("Drop Unique + Dedupe") { transformClipboard(ClipboardTransform.keepDuplicateLinesCollapsed) }
                        Button("Drop Non-unique") { transformClipboard(ClipboardTransform.keepUniqueLines) }
                    }
                    Menu("Remove Lines") {
                        let counts = ClipboardTransform.multilineRemoveValues()
                        ForEach(counts, id: \.self) { n in
                            let label = "First \(n)"
                            Button(label) {
                                transformClipboard { ClipboardTransform.removeFirstLines($0, count: n) }
                            }
                        }
                        Divider()
                        ForEach(counts, id: \.self) { n in
                            let label = "Last \(n)"
                            Button(label) {
                                transformClipboard { ClipboardTransform.removeLastLines($0, count: n) }
                            }
                        }
                    }

                    Menu("Head Lines") {
                        let counts = ClipboardTransform.multilineRemoveValues()
                        ForEach(counts, id: \.self) { n in
                            let label = "\(n)"
                            Button(label) {
                                transformClipboard { ClipboardTransform.headLines($0, count: n) }
                            }
                        }
                    }

                    Menu("Tail Lines") {
                        let counts = ClipboardTransform.multilineRemoveValues()
                        ForEach(counts, id: \.self) { n in
                            let label = "\(n)"
                            Button(label) {
                                transformClipboard { ClipboardTransform.tailLines($0, count: n) }
                            }
                        }
                    }
                    Divider()
                }

                Menu("Indent Lines") {
                    Section("Indent") {
                        Button("1 Tab") {
                            transformClipboard { input in
                                ClipboardTransform.indentLines(input, indent: "\t")
                            }
                        }
                        Button("2 Spaces") {
                            transformClipboard { input in
                                ClipboardTransform.indentLines(input, indent: "  ")
                            }
                        }
                        Button("4 Spaces") {
                            transformClipboard { input in
                                ClipboardTransform.indentLines(input, indent: "    ")
                            }
                        }
                    }
                    Section("Un-indent") {
                        Button("1 Tab") {
                            transformClipboard { input in
                                ClipboardTransform.unindentLines(input, indent: "\t")
                            }
                        }
                        Button("2 Spaces") {
                            transformClipboard { input in
                                ClipboardTransform.unindentLines(input, indent: "  ")
                            }
                        }
                        Button("4 Spaces") {
                            transformClipboard { input in
                                ClipboardTransform.unindentLines(input, indent: "    ")
                            }
                        }
                    }
                }

                Menu("Wrap Lines") {
                    ForEach(ClipboardTransform.builtinMultilineWrappers(), id: \.label) { item in
                        Button(item.label) {
                            transformClipboard {
                                ClipboardTransform.wrapLines($0, prefix: item.prefix, suffix: item.suffix)
                            }
                        }
                    }
                    let custom = ClipboardTransform.customMultilineWrappers()
                    if !custom.isEmpty {
                        Divider()
                        ForEach(custom, id: \.label) { item in
                            Button(item.label) {
                                transformClipboard {
                                    ClipboardTransform.wrapLines($0, prefix: item.prefix, suffix: item.suffix)
                                }
                            }
                        }
                    }
                }

                Menu("Unwrap Lines") {
                    ForEach(ClipboardTransform.builtinMultilineWrappers(), id: \.label) { item in
                        Button(item.label) {
                            transformClipboard {
                                ClipboardTransform.unwrapLines($0, prefix: item.prefix, suffix: item.suffix)
                            }
                        }
                    }
                    let customUnwrap = ClipboardTransform.customMultilineWrappers()
                    if !customUnwrap.isEmpty {
                        Divider()
                        ForEach(customUnwrap, id: \.label) { item in
                            Button(item.label) {
                                transformClipboard {
                                    ClipboardTransform.unwrapLines($0, prefix: item.prefix, suffix: item.suffix)
                                }
                            }
                        }
                    }
                }
                Menu("Trim Lines") {
                    Button("Whitespace") { transformClipboard(ClipboardTransform.trimLines) }
                    Button("Trailing Commas") { transformClipboard(ClipboardTransform.trimTrailingCommas) }
                    Button("Trailing Semicolons") { transformClipboard(ClipboardTransform.trimTrailingSemicolons) }
                }
                Divider()
                if clipboardAnalysis.lineCount > 1 || shouldShowAll {
                    Menu("Join Lines") {
                        Section("Join With") {
                            ForEach(ClipboardTransform.builtinMultilineJoiners(), id: \.label) { item in
                                Button(item.label) {
                                    transformClipboard { ClipboardTransform.joinLines($0, delimiter: item.delimiter) }
                                }
                            }
                            let custom = ClipboardTransform.customMultilineJoiners()
                            if !custom.isEmpty {
                                Divider()
                                ForEach(custom, id: \.label) { item in
                                    Button(item.label) {
                                        transformClipboard { ClipboardTransform.joinLines($0, delimiter: item.delimiter) }
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("→ JSON Array (typed)") {
                            transformClipboardIfValid { input in
                                ClipboardTransform.linesToTypedJsonArray(input)
                            }
                        }
                        Button("→ JSON Array (strings)") {
                            transformClipboardIfValid { input in
                                ClipboardTransform.linesToStringJsonArray(input)
                            }
                        }
                        Divider()
                    }
                }

                Menu("Awk Lines") {
                    ForEach(1...8, id: \.self) { n in
                        Button("{print $\(n)}") {
                            transformClipboard { input in
                                ClipboardTransform.awk(input, command: "{print $\(n)}")
                            }
                        }
                    }
                    Divider()
                    let customAwkPatterns = ClipboardTransform.customAwkPrintPatterns()
                    ForEach(customAwkPatterns, id: \.label) { pattern in
                        Button(pattern.label) {
                            transformClipboard { input in
                                ClipboardTransform.awk(input, command: pattern.command)
                            }
                        }
                    }
                }

                if hasCarriageReturns || shouldShowAll {
                    Divider()
                    Button(appendSparkleIf("CRLF → LF (strip \\r)", condition: hasCarriageReturns && !shouldShowAll)) {
                        transformClipboard(ClipboardTransform.windowsNewlinesToUnix)
                    }
                }
            }
            Menu(encodeHashMenuLabel) {
                Section("URL") {
                    Button("Encode") { transformClipboard(ClipboardTransform.urlEncode) }
                    if showURLDecode {
                        Button(appendSparkleIf("Decode", condition: isPossiblyURLEncoded && !shouldShowAll)) {
                            transformClipboard(ClipboardTransform.urlDecode)
                        }
                    }
                }
                Section("Base64") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64Encode) }
                    if showBase64Decode {
                        Button(appendSparkleIf("Decode", condition: clipboardAnalysis.dataType == .base64 && !shouldShowAll)) {
                            transformClipboard(ClipboardTransform.base64Decode)
                        }
                    }
                }
                Section("Base64 URL-Safe") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64URLEncode) }
                    if showBase64URLDecode {
                        Button(appendSparkleIf("Decode", condition: clipboardAnalysis.dataType == .base64URL && !shouldShowAll)) {
                            transformClipboard(ClipboardTransform.base64URLDecode)
                        }
                    }
                }
                if showJWTDecode {
                    Section("JWT") {
                        Button(appendSparkleIf("Decode Payload", condition: clipboardAnalysis.dataType == .jwt && !shouldShowAll)) {
                            transformClipboardIfValid(ClipboardTransform.jwtDecode)
                        }
                        Button("Decode Header") { transformClipboardIfValid(ClipboardTransform.jwtDecodeHeader) }
                    }
                }
                Divider()
                Section("Calculate Checksum") {
                    Button("MD5") { transformClipboard(ClipboardTransform.md5Checksum) }
                    Button("SHA-1") { transformClipboard(ClipboardTransform.sha1Checksum) }
                    Button("SHA-256") { transformClipboard(ClipboardTransform.sha256Checksum) }
                    Button("SHA-512") { transformClipboard(ClipboardTransform.sha512Checksum) }
                    Button("CRC32") { transformClipboard(ClipboardTransform.crc32) }
                }
                Divider()
                Section("Hash Credentials") {
                    Button("Argon2id") { transformClipboardIfValid(ClipboardTransform.argon2idHash) }
                    Button("bcrypt") { transformClipboardIfValid(ClipboardTransform.bcryptHash) }
                }
            }
            if showJSONYAMLMenu {
                Menu(jsonYAMLMenuLabel) {
                    if showJSONSection {
                        Section("JSON") {
                            if showJSONYAMLPrettify {
                                Button("Prettify") { transformClipboard(ClipboardTransform.jsonPrettify) }
                            }
                            if showJSONYAMLMinify {
                                Button("Minify") { transformClipboard(ClipboardTransform.jsonMinify) }
                            }
                            if shouldShowAll || !clipboardAnalysis.isArrayStructure {
                                Button("Sort Keys") { transformClipboard(ClipboardTransform.jsonSortKeys) }
                            }
                            Button("Strip Nulls") { transformClipboard(ClipboardTransform.jsonStripNulls) }
                            Button("Strip Empty Strings") { transformClipboard(ClipboardTransform.jsonStripEmptyStrings) }
                            if shouldShowAll || !clipboardAnalysis.isArrayStructure {
                                Button("Top-Level Keys") { transformClipboard(ClipboardTransform.jsonTopLevelKeys) }
                            }
                            if shouldShowAll || !isSimpleLiteralJsonArray {
                                Button("All Keys") { transformClipboard(ClipboardTransform.jsonAllKeys) }
                            }
                            if showJSONArrayToCsv {
                                Button(appendSparkleIf("Array → CSV", condition: isJsonArray && !shouldShowAll)) {
                                    transformClipboardIfValid(ClipboardTransform.jsonArrayToCsv)
                                }
                            }
                            Button("→ YAML") { transformClipboardIfValid(ClipboardTransform.jsonToYaml) }
                        }
                    }
                    if showJSONSection && showYAMLSection {
                        Divider()
                    }
                    if showYAMLSection {
                        Section("YAML") {
                            if showJSONYAMLPrettify {
                                Button("Prettify") { transformClipboard(ClipboardTransform.yamlPrettify) }
                            }
                            if showJSONYAMLMinify {
                                Button("Minify") { transformClipboard(ClipboardTransform.yamlMinify) }
                            }
                            Button("→ JSON") { transformClipboardIfValid(ClipboardTransform.yamlToJson) }
                        }
                    }
                }
            }
            if showCSVMenu {
                Menu(csvMenuLabel) {
                    if showCSVSection {
                        Section("CSV") {
                            Button("→ JSON (typed)") { transformClipboardIfValid(ClipboardTransform.csvToJson) }
                            Button("→ JSON (strings)") { transformClipboardIfValid(ClipboardTransform.csvToJsonStrings) }
                            Button("→ Tab-separated") { transformClipboard(ClipboardTransform.csvToTsv) }
                            Button("→ Pipe-separated") { transformClipboard(ClipboardTransform.csvToPsv) }
                            Button("→ Fixed-Width Table") { transformClipboardIfValid(ClipboardTransform.csvToFixedWidthTable) }
                        }
                    }
                    if showCSVSection && showTSVPSVSection {
                        Divider()
                    }
                    if showTSVPSVSection {
                        Section("Tab/Pipe-Separated") {
                            if showTSVToCsv {
                                Button("TSV → CSV") { transformClipboardIfValid(ClipboardTransform.tsvToCsv) }
                            }
                            if showPSVToCsv {
                                Button("PSV → CSV") { transformClipboardIfValid(ClipboardTransform.psvToCsv) }
                            }
                        }
                    }
                    if clipboardAnalysis.dataType == .fixedWidthTable || shouldShowAll {
                        Divider()
                        Section("Fixed-Width Table") {
                            Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToCsv) }
                            Button("Table → JSON (typed)") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToJson) }
                            Button("Table → JSON (strings)") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToJsonStrings) }
                        }
                    }
                    if showColumnsSection {
                        Divider()
                        Button("Strip Empty Columns") { stripEmptyColumns() }
                        Divider()
                        Section("Columns") {
                            ForEach(Array(csvColumnHeaders.enumerated().prefix(26)), id: \.offset) { columnIndex, columnName in
                                Menu(columnName.isEmpty ? "Column \(columnIndex + 1)" : columnName) {
                                    // Sort button
                                    Button("Sort By") {
                                        sortByColumn(columnIndex: columnIndex)
                                    }
                                    Divider()
                                    // Remove button
                                    Button("Remove") {
                                        removeColumn(columnIndex: columnIndex)
                                    }
                                    .disabled(csvColumnHeaders.count <= 1)
                                    // Extract submenu
                                    Divider()
                                    Menu("Extract") {
                                        Button("This Column") {
                                            extractColumns(fromIndex: columnIndex, toIndex: columnIndex)
                                        }
                                        let columnsAfter = Array(csvColumnHeaders.enumerated().dropFirst(columnIndex + 1).prefix(25))
                                        if !columnsAfter.isEmpty {
                                            Divider()
                                            Section("Through") {
                                                ForEach(columnsAfter, id: \.offset) { targetIndex, targetName in
                                                    Button(targetName.isEmpty ? "Column \(targetIndex + 1)" : targetName) {
                                                        extractColumns(fromIndex: columnIndex, toIndex: targetIndex)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    // Swap submenu
                                    Menu("Swap") {
                                        ForEach(Array(csvColumnHeaders.enumerated().prefix(26)), id: \.offset) { targetIndex, targetName in
                                            if targetIndex != columnIndex {
                                                Button(targetName.isEmpty ? "Column \(targetIndex + 1)" : targetName) {
                                                    swapColumns(indexA: columnIndex, indexB: targetIndex)
                                                }
                                            }
                                        }
                                    }
                                    // Move submenu
                                    Menu("Move") {
                                        Button("To the Start") {
                                            moveColumnToStart(fromIndex: columnIndex)
                                        }
                                        .disabled(columnIndex == 0)
                                        Button("To the End") {
                                            moveColumnToEnd(fromIndex: columnIndex)
                                        }
                                        .disabled(columnIndex == csvColumnHeaders.count - 1)
                                        let validBeforeColumns = csvColumnHeaders.enumerated().filter { targetIndex, _ in
                                            targetIndex != 0 &&
                                            targetIndex != columnIndex &&
                                            targetIndex != columnIndex + 1
                                        }
                                        if !validBeforeColumns.isEmpty {
                                            Divider()
                                            Section("Before") {
                                                ForEach(Array(validBeforeColumns.prefix(26)), id: \.offset) { targetIndex, targetName in
                                                    Button(targetName.isEmpty ? "Column \(targetIndex + 1)" : targetName) {
                                                        moveColumnBefore(fromIndex: columnIndex, beforeIndex: targetIndex)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if showDatabaseCLIMenu {
                Menu(databaseCLIMenuLabel) {
                    if showMySQLSection {
                        Section("mysql") {
                            Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToCsv) }
                            Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToJson) }
                        }
                    }
                    if showMySQLSection && (showPsqlSection || showSqlite3Section) {
                        Divider()
                    }
                    if showPsqlSection {
                        Section("psql") {
                            Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToCsv) }
                            Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToJson) }
                        }
                    }
                    if showPsqlSection && showSqlite3Section {
                        Divider()
                    }
                    if showSqlite3Section {
                        Section("sqlite3") {
                            Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToCsv) }
                            Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToJson) }
                        }
                    }
                }
            }
            Menu("Escaping") {
                Button("Escape Double Quotes") { transformClipboard(ClipboardTransform.escapeDoubleQuotes) }
                Button("Unescape Double Quotes") { transformClipboard(ClipboardTransform.unescapeDoubleQuotes) }
                Divider()
                Button("Escape Single Quotes") { transformClipboard(ClipboardTransform.escapeSingleQuotes) }
                Button("Unescape Single Quotes") { transformClipboard(ClipboardTransform.unescapeSingleQuotes) }
                Divider()
                Button("Escape Backslashes") { transformClipboard(ClipboardTransform.escapeBackslashes) }
                Button("Unescape Backslashes") { transformClipboard(ClipboardTransform.unescapeBackslashes) }
                Divider()
                Button("Escape $") { transformClipboard(ClipboardTransform.escapeDollar) }
                Button("Unescape $") { transformClipboard(ClipboardTransform.unescapeDollar) }
                Divider()
                Button("HTML Escape") { transformClipboard(ClipboardTransform.htmlEscape) }
                Button("HTML Unescape") { transformClipboard(ClipboardTransform.htmlUnescape) }
                #if DEBUG
                Divider()
                Button(useDemoSnippets ? "Turn Demo Menu Off" : "Turn Demo Menu On") {
                    demoMenuEnabled.toggle()
                }
                #endif
            }
        }
        }
        Menu("Set Clipboard Text") {
            Menu("Time") {
                Section("Sets Clipboard to Current Time") {
                    Divider()
                    Button("Epoch (s)") { setClipboardToEpochSeconds() }
                    Button("Epoch (ms)") { setClipboardToEpochMilliseconds() }
                    Divider()
                    Button("SQL DateTime (Local)") { setClipboardToSQLDateTimeLocal() }
                    Button("SQL DateTime (UTC)") { setClipboardToSQLDateTimeUTC() }
                    Divider()
                    Button("RFC3339 (Z)") { setClipboardToRFC3339Z() }
                    Button("RFC3339 (+offset)") { setClipboardToRFC3339WithOffset() }
                    Button("RFC3339 (tz abbrev)") { setClipboardToRFC3339WithAbbreviation() }
                    Divider()
                    Button("RFC1123 (UTC)") { setClipboardToRFC1123UTC() }
                    Divider()
                    Button("YYYY/MM/DD hh:mm:ss (Local)") { setClipboardToYYYYMMDDHHmmssLocal() }
                    Button("YYYY/MM/DD hh:mm:ss (UTC)") { setClipboardToYYYYMMDDHHmmssUTC() }
                    Button("YY/MM/DD hh:mm:ss (Local)") { setClipboardToYYMMDDHHmmssLocal() }
                    Button("YY/MM/DD hh:mm:ss (UTC)") { setClipboardToYYMMDDHHmmssUTC() }
                    Divider()
                    Button("YYYY/MM/DD (Local)") { setClipboardToYYYYMMDDLocal() }
                    Button("YYYY/MM/DD (UTC)") { setClipboardToYYYYMMDDUTC() }
                    Button("YYYY/MM/DD/HH (Local)") { setClipboardToYYYYMMDDHHLocal() }
                    Button("YYYY/MM/DD/HH (UTC)") { setClipboardToYYYYMMDDHHUTC() }
                    Button("YY/MM/DD (Local)") { setClipboardToYYMMDDLocal() }
                    Button("YY/MM/DD (UTC)") { setClipboardToYYMMDDUTC() }
                }
            }
            Menu("Symbol") {
                Menu("General") {
                    Button("Em dash —") { setClipboardTo("—") }
                    Button("En dash –") { setClipboardTo("–") }
                    Button("Ellipsis …") { setClipboardTo("…") }
                }
                Menu("Shapes") {
                    Button("Check mark ✓") { setClipboardTo("✓") }
                    Button("Middle dot ·") { setClipboardTo("·") }
                    Button("Bullet •") { setClipboardTo("•") }
                    Button("Open Bullet ◦") { setClipboardTo("◦") }
                    Button("Lg Bullet ●") { setClipboardTo("●") }
                    Button("Lg Open Bullet ○") { setClipboardTo("○") }
                    Button("Square Bullet ▪") { setClipboardTo("▪") }
                    Button("Open Square ▫") { setClipboardTo("▫") }
                    Button("Triangle Bullet ▸") { setClipboardTo("▸") }
                    Button("Lg Triangle Bullet ▶") { setClipboardTo("▶") }
                    Button("Diamond Bullet ◆") { setClipboardTo("◆") }
                    Button("Filled Star ★") { setClipboardTo("★") }
                    Button("Open Star ☆") { setClipboardTo("☆") }
                }
                Menu("Math") {
                    Button("Squared ²") { setClipboardTo("²") }
                    Button("Cubed ³") { setClipboardTo("³") }
                    Button("Subscript 2 ₂") { setClipboardTo("₂") }
                    Button("Subscript 3 ₃") { setClipboardTo("₃") }
                    Divider()
                    Button("Plus-minus ±") { setClipboardTo("±") }
                    Button("Multiply ×") { setClipboardTo("×") }
                    Button("Divide ÷") { setClipboardTo("÷") }
                    Divider()
                    Button("Not equal ≠") { setClipboardTo("≠") }
                    Button("Approximately ≈") { setClipboardTo("≈") }
                    Button("Less-or-equal ≤") { setClipboardTo("≤") }
                    Button("Greater-or-equal ≥") { setClipboardTo("≥") }
                    Divider()
                    Button("Infinity ∞") { setClipboardTo("∞") }
                }
                Menu("Legal") {
                    Button("Copyright ©") { setClipboardTo("©") }
                    Button("Registered ®") { setClipboardTo("®") }
                    Button("Trademark ™") { setClipboardTo("™") }
                    Button("Section §") { setClipboardTo("§") }
                }
                Menu("Spaces") {
                    Button("Tab") { setClipboardTo("\t") }
                    Button("Non-breaking") { setClipboardTo("\u{00A0}") }
                    Button("Pilcrow ¶") { setClipboardTo("¶") }
                }
                Menu("Arrows") {
                    Button("Right →") { setClipboardTo("→") }
                    Button("Left ←") { setClipboardTo("←") }
                    Button("Up ↑") { setClipboardTo("↑") }
                    Button("Down ↓") { setClipboardTo("↓") }
                    Button("Right double ⇒") { setClipboardTo("⇒") }
                    Button("Left double ⇐") { setClipboardTo("⇐") }
                }
                Menu("Units") {
                    Button("Degrees °") { setClipboardTo("°") }
                    Button("Micro µ") { setClipboardTo("µ") }
                    Button("Per mille ‰") { setClipboardTo("‰") }
                    Button("Basis pts. ‱") { setClipboardTo("‱") }
                    Divider()
                    Section("Currency") {
                        Button("Euro €") { setClipboardTo("€") }
                        Button("Pound £") { setClipboardTo("£") }
                        Button("Yen/Yuan ¥") { setClipboardTo("¥") }
                        Button("Rupee ₹") { setClipboardTo("¢") }
                        Button("Won ₩") { setClipboardTo("¢") }
                        Button("Baht ฿") { setClipboardTo("¢") }
                        Button("BTC ₿") { setClipboardTo("¢") }
                        Button("Dollar $") { setClipboardTo("$") }
                        Button("Cent ¢") { setClipboardTo("¢") }
                    }
                }
            }
            Menu("Random") {
                Section("UUID") {
                    Button("Lowercase") { setClipboardToRandomUUIDLowercase() }
                    Button("Uppercase") { setClipboardToRandomUUID() }
                }
                Divider()
                Button("ULID") { setClipboardToRandomULID() }
                Button("NanoID") { setClipboardToRandomNanoID() }
                Divider()
                Section("Hex Strings") {
                    Button("6 Bytes / 12 Chr") { setClipboardToRandomHex(byteCount: 6) }
                    Button("8 Bytes / 16 Chr") { setClipboardToRandomHex(byteCount: 8) }
                    Button("16 Bytes / 32 Chr") { setClipboardToRandomHex(byteCount: 16) }
                    Button("32 Bytes / 64 Chr") { setClipboardToRandomHex(byteCount: 32) }
                }
                Divider()
                Section("Generate Password") {
                    Button("Very Complex") { setClipboardToRandomVeryComplexPassword() }
                    Button("Complex") { setClipboardToRandomComplexPassword() }
                    Button("Alphanumeric") { setClipboardToRandomAlphanumericPassword() }
                }
            }
            Menu("Filler") {
                Button("Lorem Ipsum (Short)") { setClipboardTo(ClipboardSet.loremIpsumPlaceholderShort) }
                Button("Lorem Ipsum (Medium)") { setClipboardTo(ClipboardSet.loremIpsumPlaceholderMedium) }
                Button("Lorem Ipsum (Full)") { setClipboardTo(ClipboardSet.loremIpsumPlaceholderFull) }
                Button("The Quick Brown Fox") { setClipboardTo(ClipboardSet.quickBrownFoxPlaceholder) }
                Button("Pack My Box") { setClipboardTo(ClipboardSet.packMyBoxPlaceholder) }
                Button("Sphinx of Black Quartz") { setClipboardTo(ClipboardSet.sphinxOfBlackQuartzPlaceholder) }
                Button("Waltz, Bad Nymph") { setClipboardTo(ClipboardSet.waltzBadNymphPlaceholder) }
                Button("Jackdaws") { setClipboardTo(ClipboardSet.jackdawsPlaceholder) }
            }
            if shouldShowAll {
                Divider()
                Menu("Test Data") {
                    Button("JSON Array") { setClipboardTo(TestData.jsonArray) }
                    Button("JSON Object") { setClipboardTo(TestData.jsonObject) }
                    Button("CSV") { setClipboardTo(TestData.csv) }
                    Button("TSV") { setClipboardTo(TestData.tsv) }
                    Button("PSV") { setClipboardTo(TestData.psv) }
                    Button("YAML") { setClipboardTo(TestData.yaml) }
                    Button("Fixed-Width (Docker ps)") { setClipboardTo(TestData.fixedWidthDockerContainers) }
                    Button("Awkable Lines") { setClipboardTo(TestData.awkWhitespaceSample) }
                    Button("Awkable Lines (slashes)") { setClipboardTo(TestData.awkDelimitedSample) }
                    Button("URL with Params") { setClipboardTo(TestData.urlWithParams) }
                    Button("JWT") { setClipboardTo(TestData.jwt) }
                    Button("Base64") { setClipboardTo(ClipboardTransform.base64Encode(TestData.plainText)) }
                    Button("Base64 URL") { setClipboardTo(ClipboardTransform.base64URLEncode(TestData.plainText)) }
                    Button("URL-encoded") { setClipboardTo(TestData.urlEncoded) }
                    Button("Plain text") { setClipboardTo(TestData.plainText) }
                    Button("Text List (Instruments)") { setClipboardTo(TestData.instrumentsList) }
                    Button("Text w/ 0-Width Chrs") { setClipboardTo(TestData.zeroWidthSample) }
                    Button("MySQL CLI Table") { setClipboardTo(TestData.mysqlCLI) }
                    Button("psql CLI Table") { setClipboardTo(TestData.psqlCLI) }
                    Button("sqlite3 CLI Table") { setClipboardTo(TestData.sqlite3CLI) }
                }
            }
        }
        Divider()
        Button("New Snippet") {
            editorStore.editingSnippet = nil
            openWindow(id: "editor")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Button("Clipboard → New Snippet", action: quickSaveFromClipboard)
        Divider()
        if displayedSnippets.isEmpty {
            Text("No snippets yet")
        } else {
            ForEach(recentDisplayedSnippets) { snippet in
                snippetMenu(snippet)
            }
            let limit = min(
                max(recentSnippetsMenuCount, Self.recentSnippetsMenuCountRange.lowerBound),
                Self.recentSnippetsMenuCountRange.upperBound
            )
            if displayedSnippets.count > limit {
                Divider()
                Menu("All Snippets") {
                    ForEach(displayedSnippets) { snippet in
                        snippetMenu(snippet)
                    }
                }
            }
        }
        Divider()
        Button {
            openWindow(id: "settings-clipboard-envy")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings-clipboard-envy" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        Button {
            openWindow(id: "tips-clipboard-envy")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "tips-clipboard-envy" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            Label("Tips", systemImage: "lightbulb")
        }
        Button {
            openWindow(id: "about-clipboard-envy")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.identifier?.rawValue == "about-clipboard-envy" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        } label: {
            Label("About \(BuildInfo.appName)", systemImage: "info.circle")
        }
        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit \(BuildInfo.appName)", systemImage: "xmark.circle")
        }
        .onAppear {
            snippetsStore.refresh()
            refreshClipboardAnalysis()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardEnvyMenuWillOpen)) { _ in
            refreshClipboardAnalysis()
        }
    }

    // MARK: - Actions

    private struct ClipboardMenuModifiers {
        let shouldCopyBeforeTransform: Bool
        let shouldPasteAfterOperation: Bool

        init(flags: NSEvent.ModifierFlags) {
            shouldCopyBeforeTransform = flags.contains(.option)
            shouldPasteAfterOperation = flags.contains(.shift)
        }
    }

    private func currentMenuModifiers() -> ClipboardMenuModifiers {
        ClipboardMenuModifiers(flags: NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags)
    }

    private func sendPasteKeystroke() {
        do {
            try KeyboardShortcut.commandV()
        } catch {
            #if DEBUG
            print("[KeyboardShortcut] Paste failed: \(error)")
            #endif
        }
    }

    private func sendCopyKeystroke() {
        do {
            try KeyboardShortcut.commandC()
        } catch {
            #if DEBUG
            print("[KeyboardShortcut] Copy failed: \(error)")
            #endif
        }
    }

    private func quickSaveFromClipboard() {
        if let str = ClipboardIO.readString(), !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let snippet = Snippet(body: str, timestamp: Date())
            modelContext.insert(snippet)
            snippetsStore.refresh()
            ClipboardSound.playClipboardWritten(muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func transformClipboard(_ transform: @escaping (String) -> String) {
        let modifiers = currentMenuModifiers()

        if modifiers.shouldCopyBeforeTransform {
            sendCopyKeystroke()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let ok = ClipboardTransform.apply(transform, muted: muteSounds)
                refreshClipboardAnalysis()
                if ok, modifiers.shouldPasteAfterOperation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        sendPasteKeystroke()
                    }
                }
            }
            return
        }

        let ok = ClipboardTransform.apply(transform, muted: muteSounds)
        refreshClipboardAnalysis()
        if ok, modifiers.shouldPasteAfterOperation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                sendPasteKeystroke()
            }
        }
    }

    private func transformClipboardIfValid(_ transform: @escaping (String) -> String?) {
        let modifiers = currentMenuModifiers()

        if modifiers.shouldCopyBeforeTransform {
            sendCopyKeystroke()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let ok = ClipboardTransform.applyIfValid(transform, muted: muteSounds)
                refreshClipboardAnalysis()
                if ok, modifiers.shouldPasteAfterOperation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        sendPasteKeystroke()
                    }
                }
            }
            return
        }

        let ok = ClipboardTransform.applyIfValid(transform, muted: muteSounds)
        refreshClipboardAnalysis()
        if ok, modifiers.shouldPasteAfterOperation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                sendPasteKeystroke()
            }
        }
    }

    private func transformClipboardIfValid(_ transform: @escaping (String) throws -> String) {
        let modifiers = currentMenuModifiers()

        if modifiers.shouldCopyBeforeTransform {
            sendCopyKeystroke()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                let ok = ClipboardTransform.applyIfValid(transform, muted: muteSounds)
                refreshClipboardAnalysis()
                if ok, modifiers.shouldPasteAfterOperation {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        sendPasteKeystroke()
                    }
                }
            }
            return
        }

        let ok = ClipboardTransform.applyIfValid(transform, muted: muteSounds)
        refreshClipboardAnalysis()
        if ok, modifiers.shouldPasteAfterOperation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                sendPasteKeystroke()
            }
        }
    }

    private func refreshClipboardAnalysis() {
        let modifiers = NSEvent.modifierFlags
        shouldShowAll = modifiers.contains(.option)
        let clipboardText = ClipboardIO.readString()
        clipboardAnalysis = ClipboardAnalyzer.analyze(clipboardText)

        if clipboardAnalysis.isDelimitedData, let text = clipboardText {
            csvColumnHeaders = ClipboardTransform.columnHeaders(text, maxColumns: 26)
        } else {
            csvColumnHeaders = []
        }
    }

    // MARK: - Column Operations

    private func stripEmptyColumns() {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.stripEmptyColumns(text) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func sortByColumn(columnIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.sortByColumn(text, columnIndex: columnIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func removeColumn(columnIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.removeColumn(text, columnIndex: columnIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func extractColumns(fromIndex: Int, toIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.extractColumnRange(text, fromIndex: fromIndex, toIndex: toIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func swapColumns(indexA: Int, indexB: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.swapColumns(text, indexA: indexA, indexB: indexB) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func moveColumnToStart(fromIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.moveColumnToStart(text, fromIndex: fromIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func moveColumnToEnd(fromIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.moveColumnToEnd(text, fromIndex: fromIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func moveColumnBefore(fromIndex: Int, beforeIndex: Int) {
        if let text = ClipboardIO.readString(),
           let result = ClipboardTransform.moveColumnBefore(text, fromIndex: fromIndex, beforeIndex: beforeIndex) {
            _ = ClipboardIO.writeString(result)
            ClipboardSound.playClipboardWritten(muted: muteSounds)
            refreshClipboardAnalysis()
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func setClipboardToEpochSeconds() {
        setClipboardTo(ClipboardSet.epochSeconds())
    }
    private func setClipboardToEpochMilliseconds() {
        setClipboardTo(ClipboardSet.epochMilliseconds())
    }
    private func setClipboardToSQLDateTimeLocal() {
        setClipboardTo(ClipboardSet.sqlDateTimeLocal())
    }
    private func setClipboardToSQLDateTimeUTC() {
        setClipboardTo(ClipboardSet.sqlDateTimeUTC())
    }
    private func setClipboardToRFC3339Z() {
        setClipboardTo(ClipboardSet.rfc3339Z())
    }
    private func setClipboardToRFC3339WithOffset() {
        setClipboardTo(ClipboardSet.rfc3339WithOffset())
    }
    private func setClipboardToRFC3339WithAbbreviation() {
        setClipboardTo(ClipboardSet.rfc3339WithAbbreviation())
    }
    private func setClipboardToRFC1123Local() {
        setClipboardTo(ClipboardSet.rfc1123Local())
    }
    private func setClipboardToRFC1123UTC() {
        setClipboardTo(ClipboardSet.rfc1123UTC())
    }
    private func setClipboardToYYYYMMDDHHmmssLocal() {
        setClipboardTo(ClipboardSet.yyyyMMddHHmmssLocal())
    }
    private func setClipboardToYYYYMMDDHHmmssUTC() {
        setClipboardTo(ClipboardSet.yyyyMMddHHmmssUTC())
    }
    private func setClipboardToYYMMDDHHmmssLocal() {
        setClipboardTo(ClipboardSet.yyMMddHHmmssLocal())
    }
    private func setClipboardToYYMMDDHHmmssUTC() {
        setClipboardTo(ClipboardSet.yyMMddHHmmssUTC())
    }
    private func setClipboardToYYYYMMDDLocal() {
        setClipboardTo(ClipboardSet.yyyyMMddLocal())
    }
    private func setClipboardToYYYYMMDDUTC() {
        setClipboardTo(ClipboardSet.yyyyMMddUTC())
    }
    private func setClipboardToYYYYMMDDHHLocal() {
        setClipboardTo(ClipboardSet.yyyyMMddHHLocal())
    }
    private func setClipboardToYYYYMMDDHHUTC() {
        setClipboardTo(ClipboardSet.yyyyMMddHHUTC())
    }
    private func setClipboardToYYMMDDLocal() {
        setClipboardTo(ClipboardSet.yyMMddLocal())
    }
    private func setClipboardToYYMMDDUTC() {
        setClipboardTo(ClipboardSet.yyMMddUTC())
    }
    private func setClipboardToRandomUUID() {
        setClipboardTo(ClipboardSet.randomUUID())
    }
    private func setClipboardToRandomUUIDLowercase() {
        setClipboardTo(ClipboardSet.randomUUIDLowercase())
    }

    private func setClipboardToRandomHex(byteCount: Int) {
        if let s = ClipboardSet.randomHexString(byteCount: byteCount) {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomULID() {
        if let s = ClipboardSet.randomULID() {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomNanoID() {
        if let s = ClipboardSet.randomNanoID() {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomVeryComplexPassword() {
        if let s = ClipboardSet.randomVeryComplexPassword() {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomComplexPassword() {
        if let s = ClipboardSet.randomComplexPassword() {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomAlphanumericPassword() {
        if let s = ClipboardSet.randomAlphanumericPassword() {
            setClipboardTo(s)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func setClipboardTo(_ string: String) {
        ClipboardSet.setAndNotify(string, muted: muteSounds)
        if currentMenuModifiers().shouldPasteAfterOperation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                sendPasteKeystroke()
            }
        }
    }

    private func confirmAndDelete(_ snippet: Snippet) {
        if useDemoSnippets { return }
        let modifiers: NSEvent.ModifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        let bypassConfirmation = modifiers.contains(.option) || modifiers.contains(.shift)

        if bypassConfirmation {
            modelContext.delete(snippet)
            snippetsStore.refresh()
        } else {
            let alert = NSAlert()
            alert.messageText = "Delete this snippet?"
            alert.informativeText = "This will permanently delete: \(snippetMenuTitle(for: snippet))"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                modelContext.delete(snippet)
                snippetsStore.refresh()
            }
        }
    }

    private func copyToClipboard(_ snippet: Snippet) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.body, forType: .string)
        ClipboardSound.playClipboardWritten(muted: muteSounds)
        if currentMenuModifiers().shouldPasteAfterOperation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                sendPasteKeystroke()
            }
        }
    }

    private func moveUp(_ snippet: Snippet) {
        if useDemoSnippets { return }
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }), idx > 0 else { return }
        let above = snippets[idx - 1]
        swapTimestamps(between: snippet, and: above)
        snippetsStore.refresh()
    }

    private func moveDown(_ snippet: Snippet) {
        if useDemoSnippets { return }
        guard let idx = snippets.firstIndex(where: { $0.id == snippet.id }), idx < snippets.count - 1 else { return }
        let below = snippets[idx + 1]
        swapTimestamps(between: snippet, and: below)
        snippetsStore.refresh()
    }

    private func swapTimestamps(between a: Snippet, and b: Snippet) {
        let temp = a.timestamp
        a.timestamp = b.timestamp
        b.timestamp = temp
        try? modelContext.save()
    }

    @ViewBuilder
    private func snippetMenu(_ snippet: Snippet) -> some View {
        Menu(snippetMenuTitle(for: snippet)) {
            Button("Copy to Clipboard") { copyToClipboard(snippet) }
            if hasURL(snippet.body) {
                Button("Open URL") { openURL(from: snippet.body) }
            }
            Button("Edit") {
                editorStore.editingSnippet = snippet
                openWindow(id: "editor")
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            Button(role: .destructive) { confirmAndDelete(snippet) } label: {
                Text("Delete")
            }
            Divider()
            Button("Move Up") { moveUp(snippet) }
                .disabled(useDemoSnippets || displayedSnippets.first?.id == snippet.id)
            Button("Move Down") { moveDown(snippet) }
                .disabled(useDemoSnippets || displayedSnippets.last?.id == snippet.id)
        }
    }

    private func snippetMenuTitle(for snippet: Snippet) -> String {
        let limit = min(
            max(snippetMenuLabelMaxChars, Self.snippetMenuLabelMaxCharsRange.lowerBound),
            Self.snippetMenuLabelMaxCharsRange.upperBound
        )
        if let t = snippet.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return truncated(normalizedForMenu(t), limit: limit)
        }
        return truncated(normalizedForMenu(snippet.body), limit: limit)
    }

    private func hasURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    private func openURL(from text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: firstLine) else { return }
        NSWorkspace.shared.open(url)
    }

    private func normalizedForMenu(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func truncated(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        let idx = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<idx]) + "…"
    }
}

#Preview {
    let container = try! ModelContainer(for: Snippet.self, configurations: .init(isStoredInMemoryOnly: true))
    MenuBarView()
        .environmentObject(EditorStore())
        .environmentObject(SnippetsStore(container: container))
        .modelContainer(container)
}
