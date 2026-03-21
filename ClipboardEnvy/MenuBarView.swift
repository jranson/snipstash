import SwiftUI
import SwiftData
import AppKit

@MainActor
struct MenuBarView: View {
    private static let recentSnippetsMenuCountRange: ClosedRange<Int> = 0...20
    @AppStorage("recentSnippetsMenuCount") private var recentSnippetsMenuCount = 10
    private static let snippetMenuLabelMaxCharsRange: ClosedRange<Int> = 10...64
    @AppStorage("snippetMenuLabelMaxChars") private var snippetMenuLabelMaxChars = 36
    private static let clipboardPreviewMaxLinesRange: ClosedRange<Int> = 0...20
    @AppStorage("clipboardPreviewMaxLines") private var clipboardPreviewMaxLines = 5

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false
    @AppStorage("demoMenuEnabled") private var demoMenuEnabled = false

    @State private var clipboardAnalysis = ClipboardAnalysis(dataType: .nonText)
    @State private var shouldShowAll = false
    @State private var shouldPasteAfterOperation = false
    @State private var optionMonitors: [Any] = []

    private var snippets: [Snippet] { snippetsStore.snippets }

    // MARK: - Sparkle helpers

    private func symbolMenuLabel(symbol: String, name: String, padding: String = "") -> String {
        "\(symbol)  \(padding)\(name)"
    }

    @ViewBuilder
    private func toggleVisibility<Content: View>(_ isHidden: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        if isHidden {
            content().modifier(HiddenModifier())
        } else {
            content()
        }
    }

    private struct HiddenModifier: ViewModifier {
        func body(content: Content) -> some View {
            content.hidden()
        }
    }

    // MARK: - Menu Visibility Computed Properties

    private var timeMenuLabel: String {
        timeMenuTitle(shouldShowAll: shouldShowAll)
    }

    private func timeMenuTitle(shouldShowAll: Bool) -> String {
        TransformMenuTitles.appendSparkleIf(TransformMenuTitles.time, condition: !shouldShowAll && clipboardAnalysis.dataType == .time)
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

    private var isPossiblyURLEncoded: Bool {
        clipboardAnalysis.isPossiblyURLEncoded
    }

    private var showURLDecode: Bool {
        shouldShowAll || isPossiblyURLEncoded
    }

    // MARK: - Encode & Hash Menu

    private var encodeHashMenuLabel: String {
        TransformMenuTitles.appendSparkleIf(
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
        urlsMenuTitle(shouldShowAll: shouldShowAll)
    }

    private func urlsMenuTitle(shouldShowAll: Bool) -> String {
        TransformMenuTitles.appendSparkleIf(TransformMenuTitles.urls, condition: !shouldShowAll && isURL)
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

    private var showJSONYAMLPrettify: Bool {
        shouldShowAll || clipboardAnalysis.isMinified
    }

    private var showJSONYAMLMinify: Bool {
        shouldShowAll || !clipboardAnalysis.isMinified
    }

    private var showJSONArrayToCsv: Bool {
        // For normal mode, hide CSV transforms for simple literal arrays like
        // ["Commas", "Spaces", ...].
        shouldShowAll || (clipboardAnalysis.isArrayStructure && !isSimpleLiteralJsonArray)
    }

    private var generalTextMenuLabel: String {
        generalTextMenuTitle(shouldShowAll: shouldShowAll)
    }

    private func generalTextMenuTitle(shouldShowAll _: Bool) -> String {
        TransformMenuTitles.appendSparkleIf(TransformMenuTitles.generalText, condition: isSimpleLiteralJsonArray || hasZeroWidthCharacters)
    }

    private var jsonYAMLMenuLabel: String {
        jsonYAMLMenuTitle(shouldShowAll: shouldShowAll)
    }

    private func jsonYAMLMenuTitle(shouldShowAll: Bool) -> String {
        let contextTitle: String = {
            switch clipboardAnalysis.dataType {
            case .json: return TransformMenuTitles.json
            case .yaml: return TransformMenuTitles.yaml
            default: return TransformMenuTitles.jsonOrYaml
            }
        }()
        let menuTitleBase = shouldShowAll ? TransformMenuTitles.jsonOrYaml : contextTitle
        let shouldSparkle = clipboardAnalysis.dataType == .json || clipboardAnalysis.dataType == .yaml

        return TransformMenuTitles.appendSparkleIf(menuTitleBase, condition: shouldSparkle)
    }

    private var csvMenuLabel: String {
        csvMenuTitle(shouldShowAll)
    }

    private func csvMenuTitle(_ shouldShowAll: Bool) -> String {
        _ = shouldShowAll
        let titleBase: String = {
            switch clipboardAnalysis.dataType {
            case .fixedWidthTable:
                if let tableName = clipboardAnalysis.tableTypeName {
                    return tableName
                }
                return "Table"
            case .csv: return TransformMenuTitles.csv
            case .tsv: return "TSV"
            case .psv: return "PSV"
            default: return TransformMenuTitles.csv
            }
        }()

        let shouldSparkle = clipboardAnalysis.dataType == .csv
            || clipboardAnalysis.dataType == .tsv
            || clipboardAnalysis.dataType == .psv
            || clipboardAnalysis.dataType == .fixedWidthTable

        return TransformMenuTitles.appendSparkleIf(titleBase, condition: shouldSparkle)
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

    private var showJoinAndCRMenus: Bool {
        shouldShowAll || clipboardAnalysis.lineCount > 1
    }

    private var showMultiLineTransformMenus: Bool {
        shouldShowAll || clipboardAnalysis.lineCount > 1
    }

    @State private var csvColumnHeaders: [String] = []

    private var showStripColumns: Bool {
        shouldShowAll || (clipboardAnalysis.isDelimitedData && !csvColumnHeaders.isEmpty)
    }

    private var showColumnsSection: Bool {
        !csvColumnHeaders.isEmpty
    }

    private var databaseCLIMenuLabel: String {
        databaseCLIMenuTitle()
    }

    private var transformRootMenuLabel: String {
        if shouldShowAll && shouldPasteAfterOperation {
            return TransformMenuTitles.transformRootCopyPaste
        }
        if shouldShowAll {
            return TransformMenuTitles.transformRootCopy
        }
        if shouldPasteAfterOperation {
            return TransformMenuTitles.transformRootPaste
        }
        return TransformMenuTitles.transformRoot
    }

    private var setClipboardMenuLabel: String {
        shouldPasteAfterOperation ? TransformMenuTitles.setRootPaste : TransformMenuTitles.setRoot
    }

    private func databaseCLIMenuTitle() -> String {
        TransformMenuTitles.appendSparkleIf(
            TransformMenuTitles.databaseCLI,
            condition: clipboardAnalysis.dataType == .databaseCLITable
        )
    }

    private func transformSubmenusVisibleWithoutOption() -> Set<String> {
        var visible: Set<String> = []
        if clipboardAnalysis.dataType == .time {
            visible.insert(TransformMenuTitles.time)
        }
        if clipboardAnalysis.dataType == .url {
            visible.insert(TransformMenuTitles.urls)
        }
        if clipboardAnalysis.dataType == .json || clipboardAnalysis.dataType == .yaml {
            visible.insert(TransformMenuTitles.jsonOrYaml)
        }
        if clipboardAnalysis.dataType == .csv ||
            clipboardAnalysis.dataType == .tsv ||
            clipboardAnalysis.dataType == .psv ||
            clipboardAnalysis.dataType == .fixedWidthTable {
            visible.insert(TransformMenuTitles.csv)
        }
        if clipboardAnalysis.dataType == .databaseCLITable {
            visible.insert(TransformMenuTitles.databaseCLI)
        }
        return visible
    }

    private func transformMenuLabelsContext() -> TransformMenuLabelsContext {
        let managedLabels: [String: TransformMenuLabelVariant] = [
            TransformMenuTitles.time: .init(
                withoutOption: timeMenuTitle(shouldShowAll: false),
                withOption: timeMenuTitle(shouldShowAll: true)
            ),
            TransformMenuTitles.urls: .init(
                withoutOption: urlsMenuTitle(shouldShowAll: false),
                withOption: urlsMenuTitle(shouldShowAll: true)
            ),
            TransformMenuTitles.jsonOrYaml: .init(
                withoutOption: jsonYAMLMenuTitle(shouldShowAll: false),
                withOption: jsonYAMLMenuTitle(shouldShowAll: true)
            ),
            TransformMenuTitles.csv: .init(
                withoutOption: csvMenuTitle(false),
                withOption: csvMenuTitle(true)
            ),
            TransformMenuTitles.databaseCLI: .init(
                withoutOption: databaseCLIMenuTitle(),
                withOption: databaseCLIMenuTitle()
            )
        ]

        return TransformMenuLabelsContext(
            transformRootTitle: transformRootMenuLabel,
            setRootTitle: setClipboardMenuLabel,
            generalText: TransformMenuLabelVariant(
                withoutOption: generalTextMenuTitle(shouldShowAll: false),
                withOption: generalTextMenuTitle(shouldShowAll: true)
            ),
            managedSubmenus: managedLabels,
            showGeneralTextSplitJSONArray: shouldShowAll || isSimpleLiteralJsonArray,
            showGeneralTextZeroWidthRemove: shouldShowAll || isSimpleLiteralJsonArray || hasZeroWidthCharacters,
            showsJSONSectionWithoutOption: clipboardAnalysis.dataType == .json,
            showsYAMLSectionWithoutOption: clipboardAnalysis.dataType == .yaml,
            hasJSONOrYAMLContext: clipboardAnalysis.dataType == .json || clipboardAnalysis.dataType == .yaml,
            showJSONYAMLPrettify: showJSONYAMLPrettify,
            showJSONYAMLMinify: showJSONYAMLMinify,
            showTimeEpochSecondsTransform: showEpochSecondsTransform,
            showTimeEpochMillisecondsTransform: showEpochMillisecondsTransform,
            showTimeSQLDateTimeTransform: showSQLDateTimeTransform,
            showTimeRFC3339Transform: showRFC3339Transform,
            showTimeRFC1123Transform: showRFC1123Transform,
            showTimeSlashDateTimeTransform: showSlashDateTimeTransform,
            showURLExtractHostPort: showURLExtractHostPort,
            showURLExtractPort: showURLExtractPort,
            showURLExtractPath: showURLExtractPath,
            showURLExtractQuery: showURLExtractQuery,
            showURLExtractFragment: showURLExtractFragment,
            showURLExtractUsername: showURLExtractUsername,
            showURLExtractCredentials: showURLExtractCredentials,
            showShowURLExtractSection: showURLExtractSection,
            showURLStripParams: shouldShowAll || isUrlWithParams,
            showURLDecode: showURLDecode,
            showBase64Decode: showBase64Decode,
            showBase64URLDecode: showBase64URLDecode,
            showJWTDecode: showJWTDecode,
            showMultiLineTransformMenus: showMultiLineTransformMenus,
            showJoinAndCRMenus: showJoinAndCRMenus,
            hasCarriageReturns: hasCarriageReturns,
            isJsonArray: isJsonArray,
            isArrayStructure: clipboardAnalysis.isArrayStructure,
            isSimpleLiteralJsonArray: isSimpleLiteralJsonArray,
            showJSONArrayToCsv: showJSONArrayToCsv,
            showCSVSection: showCSVSection,
            showTSVPSVSection: showTSVPSVSection,
            showTSVToCsv: showTSVToCsv,
            showPSVToCsv: showPSVToCsv,
            showFixedWidthTableSection: shouldShowAll || clipboardAnalysis.dataType == .fixedWidthTable,
            showStripColumns: showStripColumns,
            showColumnsSection: showColumnsSection,
            showsMySQLSectionWithoutOption: clipboardAnalysis.databaseFormat == "MySQL CLI",
            showsPsqlSectionWithoutOption: clipboardAnalysis.databaseFormat == "psql",
            showsSQLite3SectionWithoutOption: clipboardAnalysis.databaseFormat == "sqlite3",
            hasDatabaseCLITableContext: clipboardAnalysis.dataType == .databaseCLITable
        )
    }

    // Time format visibility - hide transform to same format
    private var showEpochSecondsTransform: Bool {
        clipboardAnalysis.timeFormat != "Epoch Seconds"
    }

    private var showEpochMillisecondsTransform: Bool {
        clipboardAnalysis.timeFormat != "Epoch Milliseconds"
    }

    private var showSQLDateTimeTransform: Bool {
        clipboardAnalysis.timeFormat != "SQL DateTime"
    }

    private var showRFC3339Transform: Bool {
        clipboardAnalysis.timeFormat != "RFC3339 / ISO8601"
    }

    private var showRFC1123Transform: Bool {
        clipboardAnalysis.timeFormat != "RFC1123"
    }

    private var showSlashDateTimeTransform: Bool {
        clipboardAnalysis.timeFormat != "Slash DateTime"
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
        Divider()
        Menu("Clipboard Data Analysis") {
            ForEach(Array(clipboardAnalysis.analysisDisplayItems.enumerated()), id: \.offset) { _, item in
                Text("\(item.key): \(item.value)")
            }
            if !clipboardAnalysis.previewLines.isEmpty {
                Divider()
                Section("Preview") {
                    ForEach(Array(clipboardAnalysis.previewLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                    }
                }
            }
            if !clipboardAnalysis.countDisplayItems.isEmpty {
                Divider()
                ForEach(Array(clipboardAnalysis.countDisplayItems.enumerated()), id: \.offset) { _, item in
                    Text("\(item.key): \(item.value)")
                }
            }

            Divider()
            
            if clipboardAnalysis.dataType == .jwt {
                Button(TransformMenuTitles.appendSparkleIf("Decode JWT Payload", condition: true)) { transformClipboardIfValid(ClipboardTransform.jwtDecode) }
            }
            if clipboardAnalysis.dataType == .base64 {
                Button(TransformMenuTitles.appendSparkleIf("Decode Base64", condition: true)) { transformClipboard(ClipboardTransform.base64Decode) }
            }
            if clipboardAnalysis.dataType == .base64URL {
                Button(TransformMenuTitles.appendSparkleIf("Decode Base64", condition: true)) { transformClipboard(ClipboardTransform.base64URLDecode) }
            }
            if isUrlWithParams {
                Button(TransformMenuTitles.appendSparkleIf("Strip URL Params", condition: true)) { transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid) }
            }
            if hasCarriageReturns {
                Button(TransformMenuTitles.appendSparkleIf("CRLF → LF (strip \\r)", condition: true)) { transformClipboard(ClipboardTransform.windowsNewlinesToUnix) }
            }
            if hasZeroWidthCharacters {
                Button(TransformMenuTitles.appendSparkleIf("Strip Zero-width Chars", condition: true)) {
                    transformClipboard(ClipboardTransform.removeZeroWidthCharacters)
                }
            }
            if isJsonArray && (!isSimpleLiteralJsonArray || shouldShowAll) {
                Button(TransformMenuTitles.appendSparkleIf("JSON Array → CSV", condition: true)) { transformClipboardIfValid(ClipboardTransform.jsonArrayToCsv) }
            }
            if isSimpleLiteralJsonArray {
                Button(TransformMenuTitles.appendSparkleIf("Split JSON Array", condition: true)) {
                    transformClipboardIfValid { input in
                        ClipboardTransform.simpleLiteralJsonArrayToLines(input) ?? input
                    }
                }
            }
            if clipboardAnalysis.dataType != .nonText {
                Divider()
                Button {
                    openNewEditorFromClipboard()
                } label: {
                    Label("Open in Editor", systemImage: "square.and.pencil")
                }
            }
        }
        if clipboardAnalysis.dataType != .nonText {
            Menu(transformRootMenuLabel) {
                Menu(generalTextMenuLabel) {
                if isSimpleLiteralJsonArray {
                    Button(TransformMenuTitles.appendSparkleIf("Split JSON Array", condition: true)) {
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
                Menu(TransformMenuTitles.appendSparkleIf("Remove", condition: hasZeroWidthCharacters)) {
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
                        Button(TransformMenuTitles.appendSparkleIf("Zero-width Chars", condition: hasZeroWidthCharacters)) {
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
            Menu(timeMenuLabel) {
                toggleVisibility(!showEpochSecondsTransform) {
                    Button("→ Epoch (s)") { transformClipboardIfValid(ClipboardTransform.timeToEpochSeconds) }
                }
                toggleVisibility(!showEpochMillisecondsTransform) {
                    Button("→ Epoch (ms)") { transformClipboardIfValid(ClipboardTransform.timeToEpochMilliseconds) }
                }
                toggleVisibility(!showSQLDateTimeTransform) {
                    Divider()
                    Button("→ SQL DateTime (Local)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeLocal) }
                    Button("→ SQL DateTime (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeUTC) }
                }
                toggleVisibility(!showRFC3339Transform) {
                    Divider()
                    Button("→ RFC3339 (Z)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339Z) }
                    Button("→ RFC3339 (+offset)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithOffset) }
                    Button("→ RFC3339 (tz abbrev)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithAbbreviation) }
                }
                toggleVisibility(!showRFC1123Transform) {
                    Divider()
                    Button("→ RFC1123 (Local)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123Local) }
                    Button("→ RFC1123 (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123UTC) }
                }
                toggleVisibility(!showSlashDateTimeTransform) {
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
            Menu(urlsMenuLabel) {
                Section("Extract") {
                    Button("Host (Domain)") { transformClipboardIfValid(ClipboardTransform.urlExtractHostIfValid) }
                    Button("Host:Port") { transformClipboardIfValid(ClipboardTransform.urlExtractHostPortIfValid) }
                    Button("Port") { transformClipboardIfValid(ClipboardTransform.urlExtractPortIfValid) }
                    Button("Path") { transformClipboardIfValid(ClipboardTransform.urlExtractPathIfValid) }
                    Button("Params") { transformClipboardIfValid(ClipboardTransform.urlExtractQueryIfValid) }
                    Button("Hash") { transformClipboardIfValid(ClipboardTransform.urlExtractFragmentIfValid) }
                    Button("Username") { transformClipboardIfValid(ClipboardTransform.urlExtractUsernameIfValid) }
                    Button("Username:Password") { transformClipboardIfValid(ClipboardTransform.urlExtractCredentialsIfValid) }
                }
                Divider()
                Button(showURLExtractCredentials ? "Strip user:pass" : "Strip user") {
                    transformClipboardIfValid(ClipboardTransform.urlStripCredentialsIfValid)
                }
                Button(TransformMenuTitles.appendSparkleIf("Strip URL Params", condition: isUrlWithParams)) {
                    transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid)
                }
            }

            Menu("Multiline") {
                let includeFilters = ClipboardTransform.customMultilineIncludeFilters()
                let excludeFilters = ClipboardTransform.customMultilineExcludeFilters()
                let hasAnyLineFilters = !includeFilters.isEmpty || !excludeFilters.isEmpty
                Menu("Sort") {
                    Section("Sort Lines") {
                        Button("Reverse Order") { transformClipboard(ClipboardTransform.reverseLines) }
                        Button("Alphabetically") { transformClipboard(ClipboardTransform.sortLines) }
                        Button("By Frequency ↑") { transformClipboard(ClipboardTransform.sortLinesByFrequencyAscending) }
                        Button("By Frequency ↓") { transformClipboard(ClipboardTransform.sortLinesByFrequencyDescending) }
                        Button("Shuffle") { transformClipboard(ClipboardTransform.shuffleLines) }
                    }
                }
                Divider()
                if hasAnyLineFilters {
                    Menu("Filter") {
                        if !includeFilters.isEmpty {
                            Menu("Include") {
                                Section("Lines With") {
                                    ForEach(includeFilters, id: \.label) { item in
                                        Button(item.label) {
                                            transformClipboard {
                                                ClipboardTransform.includeLinesContaining($0, filter: item.filter)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if !excludeFilters.isEmpty {
                            Menu("Exclude") {
                                Section("Lines With") {
                                    ForEach(excludeFilters, id: \.label) { item in
                                        Button(item.label) {
                                            transformClipboard {
                                                ClipboardTransform.excludeLinesContaining($0, filter: item.filter)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Menu("Collapse") {
                    Section("Collapse Lines") {
                        Button("Deduplicate") { transformClipboard(ClipboardTransform.deduplicateLines) }
                        Button("Dedupe + Alpha Sort") { transformClipboard(ClipboardTransform.sortAndDeduplicateLines) }
                        Button("Drop Empty") { transformClipboard(ClipboardTransform.removeEmptyLines) }
                        Button("Drop Unique") { transformClipboard(ClipboardTransform.removeUniqueLines) }
                        Button("Drop Unique + Dedupe") { transformClipboard(ClipboardTransform.keepDuplicateLinesCollapsed) }
                        Button("Drop Non-unique") { transformClipboard(ClipboardTransform.keepUniqueLines) }
                    }
                }
                Menu("Remove") {
                    Section("Remove Lines") {
                        Divider()
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
                }
                Menu("Head") {
                    Section("Return First") {
                        let counts = ClipboardTransform.multilineRemoveValues()
                        ForEach(counts, id: \.self) { n in
                            let label = "\(n) Lines"
                            Button(label) {
                                transformClipboard { ClipboardTransform.headLines($0, count: n) }
                            }
                        }
                    }
                }
                Menu("Tail") {
                    Section("Return Last") {
                        let counts = ClipboardTransform.multilineRemoveValues()
                        ForEach(counts, id: \.self) { n in
                            let label = "\(n) Lines"
                            Button(label) {
                                transformClipboard { ClipboardTransform.tailLines($0, count: n) }
                            }
                        }
                    }
                }

                Menu("Join") {
                    Section("Join Lines With") {
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

                Menu("Awk") {
                    Section("Awk Lines") {
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
                }

                Divider()

                Menu("Indenting") {
                    Section("Indent Lines") {
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
                    Section("Un-indent Lines") {
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

                Menu("Surround") {
                    Section("Surround Lines") {
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
                }

                Menu("Un-surround") {
                    Section("Un-surround Lines") {
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
                }
                Menu("Trim") {
                    Section("Trim Lines") {
                        Button("Whitespace") { transformClipboard(ClipboardTransform.trimLines) }
                        Button("Trailing Commas") { transformClipboard(ClipboardTransform.trimTrailingCommas) }
                        Button("Trailing Semicolons") { transformClipboard(ClipboardTransform.trimTrailingSemicolons) }
                    }
                }
                Divider()
                Button(TransformMenuTitles.appendSparkleIf("CRLF → LF (strip \\r)", condition: hasCarriageReturns)) {
                    transformClipboard(ClipboardTransform.windowsNewlinesToUnix)
                }
            }
            Menu(jsonYAMLMenuLabel) {
                Section(TransformMenuTitles.Section.json.rawValue) {
                    Button("Prettify") { transformClipboard(ClipboardTransform.jsonPrettify) }
                    Button("Minify") { transformClipboard(ClipboardTransform.jsonMinify) }
                    Button("Sort Keys") { transformClipboard(ClipboardTransform.jsonSortKeys) }
                    Button("Strip Nulls") { transformClipboard(ClipboardTransform.jsonStripNulls) }
                    Button("Strip Empty Strings") { transformClipboard(ClipboardTransform.jsonStripEmptyStrings) }
                    Button("Top-Level Keys") { transformClipboard(ClipboardTransform.jsonTopLevelKeys) }
                    Button("All Keys") { transformClipboard(ClipboardTransform.jsonAllKeys) }
                    Button(TransformMenuTitles.appendSparkleIf("Array → CSV", condition: isJsonArray && !shouldShowAll)) {
                        transformClipboardIfValid(ClipboardTransform.jsonArrayToCsv)
                    }
                    Button("→ YAML") { transformClipboardIfValid(ClipboardTransform.jsonToYaml) }
                }
                Section(TransformMenuTitles.Section.yaml.rawValue) {
                    Button("Prettify") { transformClipboard(ClipboardTransform.yamlPrettify) }
                    Button("Minify") { transformClipboard(ClipboardTransform.yamlMinify) }
                    Button("→ JSON") { transformClipboardIfValid(ClipboardTransform.yamlToJson) }
                }
            }
            Menu(csvMenuLabel) {
                Section("CSV") {
                    Button("→ JSON (typed)") { transformClipboardIfValid(ClipboardTransform.csvToJson) }
                    Button("→ JSON (strings)") { transformClipboardIfValid(ClipboardTransform.csvToJsonStrings) }
                    Button("→ Tab-separated") { transformClipboard(ClipboardTransform.csvToTsv) }
                    Button("→ Pipe-separated") { transformClipboard(ClipboardTransform.csvToPsv) }
                    Button("→ Fixed-Width Table") { transformClipboardIfValid(ClipboardTransform.csvToFixedWidthTable) }
                }
                Divider()
                Section("Tab/Pipe-Separated") {
                    Button("TSV → CSV") { transformClipboardIfValid(ClipboardTransform.tsvToCsv) }
                    Button("PSV → CSV") { transformClipboardIfValid(ClipboardTransform.psvToCsv) }
                }
                Divider()
                Section("Fixed-Width Table") {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToCsv) }
                    Button("Table → JSON (typed)") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToJson) }
                    Button("Table → JSON (strings)") { transformClipboardIfValid(ClipboardTransform.fixedWidthTableToJsonStrings) }
                }
                toggleVisibility(!showStripColumns) {
                    Divider()
                    Button("Strip Empty Columns") { stripEmptyColumns() }
                }
                toggleVisibility(!showColumnsSection) {
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
            Menu(databaseCLIMenuLabel) {
                Section(TransformMenuTitles.Section.mysql.rawValue) {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToJson) }
                }
                Section(TransformMenuTitles.Section.psql.rawValue) {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToJson) }
                }
                Section(TransformMenuTitles.Section.sqlite3.rawValue) {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToJson) }
                }
            }
            Menu(encodeHashMenuLabel) {
                Section("URL") {
                    Button("Encode") { transformClipboard(ClipboardTransform.urlEncode) }
                    Button(TransformMenuTitles.appendSparkleIf("Decode", condition: isPossiblyURLEncoded)) {
                        transformClipboard(ClipboardTransform.urlDecode)
                    }
                }
                Section("Base64") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64Encode) }
                    Button(TransformMenuTitles.appendSparkleIf("Decode", condition: clipboardAnalysis.dataType == .base64)) {
                        transformClipboard(ClipboardTransform.base64Decode)
                    }
                }
                Section("Base64 URL-Safe") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64URLEncode) }
                    Button(TransformMenuTitles.appendSparkleIf("Decode", condition: clipboardAnalysis.dataType == .base64URL)) {
                        transformClipboard(ClipboardTransform.base64URLDecode)
                    }
                }
                Section("JWT") {
                    Button(TransformMenuTitles.appendSparkleIf("Decode Payload", condition: clipboardAnalysis.dataType == .jwt)) {
                        transformClipboardIfValid(ClipboardTransform.jwtDecode)
                    }
                    Button("Decode Header") { transformClipboardIfValid(ClipboardTransform.jwtDecodeHeader) }
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
        Menu(setClipboardMenuLabel) {
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
                    Button(symbolMenuLabel(symbol: "—", name: "Em dash")) { setClipboardTo("—") }
                    Button(symbolMenuLabel(symbol: "–", name: "En dash", padding: " ")) { setClipboardTo("–") }
                    Button(symbolMenuLabel(symbol: "…", name: "Ellipsis")) { setClipboardTo("…") }
                    Button(symbolMenuLabel(symbol: "¶", name: "Pilcrow")) { setClipboardTo("¶") }
                    Button(symbolMenuLabel(symbol: "\u{00A0}", name: "NBSP", padding: "  ")) { setClipboardTo("\u{00A0}") }
                }
                Menu("Keyboard") {
                    Button(symbolMenuLabel(symbol: "⌘", name: "Command")) { setClipboardTo("⌘") }
                    Button(symbolMenuLabel(symbol: "⊞", name: "Windows")) { setClipboardTo("⊞") }
                    Button(symbolMenuLabel(symbol: "⌥", name: "Option/Alt")) { setClipboardTo("⌥") }
                    Button(symbolMenuLabel(symbol: "⌃", name: "Control")) { setClipboardTo("⌃") }
                    Button(symbolMenuLabel(symbol: "⎋", name: "Escape")) { setClipboardTo("⎋") }
                    Button(symbolMenuLabel(symbol: "⇧", name: "Shift")) { setClipboardTo("⇧") }
                    Button(symbolMenuLabel(symbol: "⇪", name: "Caps Lock")) { setClipboardTo("⇪") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "⇥", name: "Tab")) { setClipboardTo("⇥") }
                    Button(symbolMenuLabel(symbol: "⏎", name: "Return")) { setClipboardTo("⏎") }
                    Button(symbolMenuLabel(symbol: "⌫", name: "Backspace")) { setClipboardTo("⌫") }
                    Button(symbolMenuLabel(symbol: "⌦", name: "Delete")) { setClipboardTo("⌦") }
                    Button(symbolMenuLabel(symbol: "⌧", name: "Clear")) { setClipboardTo("⌧") }
                }
                Menu("Shapes") {
                    Button(symbolMenuLabel(symbol: "✓", name: "Check mark")) { setClipboardTo("✓") }
                    Button(symbolMenuLabel(symbol: "×", name: "X Mark")) { setClipboardTo("×") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "·", name: "Middle dot", padding: "  ")) { setClipboardTo("·") }
                    Button(symbolMenuLabel(symbol: "•", name: "Bullet", padding: " ")) { setClipboardTo("•") }
                    Button(symbolMenuLabel(symbol: "◦", name: "Open Bullet", padding: " ")) { setClipboardTo("◦") }
                    Button(symbolMenuLabel(symbol: "●", name: "Lg Bullet")) { setClipboardTo("●") }
                    Button(symbolMenuLabel(symbol: "○", name: "Lg Open Bullet")) { setClipboardTo("○") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "▪", name: "Square Bullet")) { setClipboardTo("▪") }
                    Button(symbolMenuLabel(symbol: "▫", name: "Open Square")) { setClipboardTo("▫") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "▸", name: "Triangle Bullet", padding: " ")) { setClipboardTo("▸") }
                    Button(symbolMenuLabel(symbol: "▶", name: "Lg Triangle Bullet")) { setClipboardTo("▶") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "◆", name: "Diamond Bullet")) { setClipboardTo("◆") }
                    Button(symbolMenuLabel(symbol: "★", name: "Filled Star")) { setClipboardTo("★") }
                    Button(symbolMenuLabel(symbol: "☆", name: "Open Star")) { setClipboardTo("☆") }
                }
                Menu("Math") {
                    Button(symbolMenuLabel(symbol: "²", name: "Squared")) { setClipboardTo("²") }
                    Button(symbolMenuLabel(symbol: "³", name: "Cubed")) { setClipboardTo("³") }
                    Button(symbolMenuLabel(symbol: "₂", name: "Subscript 2")) { setClipboardTo("₂") }
                    Button(symbolMenuLabel(symbol: "₃", name: "Subscript 3")) { setClipboardTo("₃") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "±", name: "Plus-minus")) { setClipboardTo("±") }
                    Button(symbolMenuLabel(symbol: "×", name: "Multiply")) { setClipboardTo("×") }
                    Button(symbolMenuLabel(symbol: "÷", name: "Divide")) { setClipboardTo("÷") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "≠", name: "Not equal")) { setClipboardTo("≠") }
                    Button(symbolMenuLabel(symbol: "≈", name: "Approximately")) { setClipboardTo("≈") }
                    Button(symbolMenuLabel(symbol: "≤", name: "Less-or-equal")) { setClipboardTo("≤") }
                    Button(symbolMenuLabel(symbol: "≥", name: "Greater-or-equal")) { setClipboardTo("≥") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "∞", name: "Infinity")) { setClipboardTo("∞") }
                }
                Menu("Legal") {
                    Button(symbolMenuLabel(symbol: "©", name: "Copyright")) { setClipboardTo("©") }
                    Button(symbolMenuLabel(symbol: "®", name: "Registered")) { setClipboardTo("®") }
                    Button(symbolMenuLabel(symbol: "™", name: "Trademark")) { setClipboardTo("™") }
                    Button(symbolMenuLabel(symbol: "§", name: "Section", padding: " ")) { setClipboardTo("§") }
                }
                Menu("Arrows") {
                    Button(symbolMenuLabel(symbol: "→", name: "Right")) { setClipboardTo("→") }
                    Button(symbolMenuLabel(symbol: "←", name: "Left")) { setClipboardTo("←") }
                    Button(symbolMenuLabel(symbol: "↑", name: "Up")) { setClipboardTo("↑") }
                    Button(symbolMenuLabel(symbol: "↓", name: "Down")) { setClipboardTo("↓") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "↖", name: "Upper-Left")) { setClipboardTo("↖") }
                    Button(symbolMenuLabel(symbol: "↗", name: "Upper-Right")) { setClipboardTo("↗") }
                    Button(symbolMenuLabel(symbol: "↙", name: "Lower-Left")) { setClipboardTo("↙") }
                    Button(symbolMenuLabel(symbol: "↘", name: "Lower-Right")) { setClipboardTo("↘") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "⇒", name: "Right double")) { setClipboardTo("⇒") }
                    Button(symbolMenuLabel(symbol: "⇐", name: "Left double")) { setClipboardTo("⇐") }
                }
                Menu("Units") {
                    Button(symbolMenuLabel(symbol: "°", name: "Degrees")) { setClipboardTo("°") }
                    Button(symbolMenuLabel(symbol: "µ", name: "Micro")) { setClipboardTo("µ") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "‰", name: "Per mille")) { setClipboardTo("‰") }
                    Button(symbolMenuLabel(symbol: "‱", name: "Basis pts.")) { setClipboardTo("‱") }
                    Divider()
                    Button(symbolMenuLabel(symbol: "€", name: "Euro")) { setClipboardTo("€") }
                    Button(symbolMenuLabel(symbol: "£", name: "Pound")) { setClipboardTo("£") }
                    Button(symbolMenuLabel(symbol: "¥", name: "Yen/Yuan")) { setClipboardTo("¥") }
                    Button(symbolMenuLabel(symbol: "₹", name: "Rupee")) { setClipboardTo("¢") }
                    Button(symbolMenuLabel(symbol: "₩", name: "Won")) { setClipboardTo("¢") }
                    Button(symbolMenuLabel(symbol: "฿", name: "Baht")) { setClipboardTo("¢") }
                    Button(symbolMenuLabel(symbol: "₿", name: "BTC")) { setClipboardTo("¢") }
                    Button(symbolMenuLabel(symbol: "$", name: "Dollar")) { setClipboardTo("$") }
                    Button(symbolMenuLabel(symbol: "¢", name: "Cent")) { setClipboardTo("¢") }
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
            Divider()
            Menu("Test Data") {
                Button("Text: The Tell-tale Heart") { setClipboardTo(TestData.plainText) }
                Button("Text List: Instruments") { setClipboardTo(TestData.instrumentsList) }
                Button("Text: With Zero-Width Chrs") { setClipboardTo(TestData.zeroWidthSample) }
                Divider()
                Button("JSON Object") { setClipboardTo(TestData.jsonObject) }
                Button("JSON Array") { setClipboardTo(TestData.jsonArray) }
                Button("JWT") { setClipboardTo(TestData.jwt) }
                Divider()
                Button("YAML") { setClipboardTo(TestData.yaml) }
                Divider()
                Button("CSV") { setClipboardTo(TestData.csv) }
                Button("TSV") { setClipboardTo(TestData.tsv) }
                Button("PSV") { setClipboardTo(TestData.psv) }
                Divider()
                Button("MySQL CLI Table") { setClipboardTo(TestData.mysqlCLI) }
                Button("psql CLI Table") { setClipboardTo(TestData.psqlCLI) }
                Button("sqlite3 CLI Table") { setClipboardTo(TestData.sqlite3CLI) }
                Divider()
                Button("Fixed-Width (Docker ps)") { setClipboardTo(TestData.fixedWidthDockerContainers) }
                Button("Awkable Lines") { setClipboardTo(TestData.awkWhitespaceSample) }
                Button("Awkable Lines (slashes)") { setClipboardTo(TestData.awkDelimitedSample) }
                Divider()
                Button("URL with Params") { setClipboardTo(TestData.urlWithParams) }
                Button("URL-encoded") { setClipboardTo(TestData.urlEncoded) }
                Divider()
                Button("Base64-Encoded") { setClipboardTo(ClipboardTransform.base64Encode(TestData.plainText)) }
                Button("Base64-Encoded (URL)") { setClipboardTo(ClipboardTransform.base64URLEncode(TestData.plainText)) }
            }
        }
        Divider()
        Button("New Snippet") {
            editorStore.pendingNewSnippetPrefill = ""
            editorStore.editingSnippet = nil
            editorStore.newSnippetEditorSession &+= 1
            openWindow(id: "editor")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Button("Clipboard → New Snippet", action: quickSaveFromClipboard)
            .modifierKeyAlternate(.option) {
                Button("Clipboard → New Editor") {
                    openNewEditorFromClipboard()
                }
            }
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
            NSApp.terminate(nil)
        } label: {
            Label("Quit \(BuildInfo.appName)", systemImage: "xmark.circle")
        }
        .onAppear {
            snippetsStore.refresh()
            refreshClipboardAnalysis()
            startOptionMonitoring()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardEnvyMenuWillOpen)) { _ in
            refreshClipboardAnalysis()
            MenuOpenBridge.setTransformMenuContext(transformSubmenusVisibleWithoutOption())
            MenuOpenBridge.setTransformMenuLabelsContext(transformMenuLabelsContext())
            if optionMonitors.isEmpty {
                startOptionMonitoring()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardEnvyMenuDidClose)) { _ in
            refreshOptionStatus()
            stopOptionMonitoring()
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

    private func openNewEditorFromClipboard() {
        editorStore.pendingNewSnippetPrefill = ClipboardIO.readString() ?? ""
        editorStore.editingSnippet = nil
        editorStore.newSnippetEditorSession &+= 1
        openWindow(id: "editor")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
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
        refreshOptionStatus()
        let clipboardText = ClipboardIO.readString()
        let menuLabelLimit = min(
            max(snippetMenuLabelMaxChars, Self.snippetMenuLabelMaxCharsRange.lowerBound),
            Self.snippetMenuLabelMaxCharsRange.upperBound
        )
        let previewLineLimit = min(
            max(clipboardPreviewMaxLines, Self.clipboardPreviewMaxLinesRange.lowerBound),
            Self.clipboardPreviewMaxLinesRange.upperBound
        )
        clipboardAnalysis = ClipboardAnalyzer.analyze(
            clipboardText,
            menuLabelMaxChars: menuLabelLimit,
            clipboardPreviewMaxLines: previewLineLimit
        )

        if clipboardAnalysis.isDelimitedData, let text = clipboardText {
            csvColumnHeaders = ClipboardTransform.columnHeaders(text, maxColumns: 26)
        } else {
            csvColumnHeaders = []
        }
    }

    private func refreshOptionStatus(modifiers: NSEvent.ModifierFlags = NSEvent.modifierFlags) {
        let nextShouldShowAll = optionModifierIsPressed(modifierFlags: modifiers)
        let nextShouldPasteAfterOperation = modifiers.contains(.shift)
        if nextShouldShowAll != shouldShowAll || nextShouldPasteAfterOperation != shouldPasteAfterOperation {
            print("[MenuBarView] refreshOptionStatus shouldShowAll=\(nextShouldShowAll) shouldPasteAfterOperation=\(nextShouldPasteAfterOperation)")
            shouldShowAll = nextShouldShowAll
            shouldPasteAfterOperation = nextShouldPasteAfterOperation
            if let trackedMenu = MenuOpenBridge.currentTrackingMenuIfAvailable() {
                MenuOpenBridge.setTransformMenuContext(transformSubmenusVisibleWithoutOption())
                MenuOpenBridge.setTransformMenuLabelsContext(transformMenuLabelsContext())
                MenuOpenBridge.applyTransformOverridesIfOpen(trackedMenu: trackedMenu, shouldShowAll: nextShouldShowAll)
            }
        }
    }

    private func optionModifierIsPressed(modifierFlags: NSEvent.ModifierFlags) -> Bool {
        return modifierFlags.contains(.option)
    }

    private func startOptionMonitoring() {
        stopOptionMonitoring()
        let monitor = { (event: NSEvent) in
            refreshOptionStatus(modifiers: event.modifierFlags)
            return event
        }
        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: monitor) {
            optionMonitors.append(localMonitor)
        }
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { event in
            refreshOptionStatus(modifiers: event.modifierFlags)
        }) {
            optionMonitors.append(globalMonitor)
        }
    }

    private func stopOptionMonitoring() {
        for monitor in optionMonitors {
            NSEvent.removeMonitor(monitor)
        }
        optionMonitors.removeAll()
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
            .modifierKeyAlternate(.shift) {
                Button("Copy to Clipboard & Paste (⌘V)") {
                    copyToClipboard(snippet)
                }
            }
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
