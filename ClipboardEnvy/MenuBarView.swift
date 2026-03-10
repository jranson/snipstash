import SwiftUI
import SwiftData
import AppKit

@MainActor
struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false
    @AppStorage("demoMenuEnabled") private var demoMenuEnabled = false

    private var snippets: [Snippet] { snippetsStore.snippets }

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
        Menu("Analyze Clipboard Data") {
            Text("TODO: add analysis here")
            Text("example Format: JSON Array")
            Text("example # Elements: 47")
            Text("example Format: General Text")
            Text("example Word Count: 45")
        }
        // Button("Analyze Clipboard Data") {
        //     if let str = ClipboardIO.readString() {
        //         editorStore.initialBody = str
        //         editorStore.analyzeSessionId = UUID()
        //         editorStore.editingSnippet = nil
        //         editorStore.editorWindowTitle = "Clipboard Analysis"
        //         openWindow(id: "editor")
        //         DispatchQueue.main.async {
        //             NSApp.activate(ignoringOtherApps: true)
        //         }
        //     }
        // }
        Menu("Transform Clipboard Data") {
            Menu("General Text") {
                Button("UPPERCASE") { transformClipboard(ClipboardTransform.uppercase) }
                Button("lowercase") { transformClipboard(ClipboardTransform.lowercase) }
                Button("Trimmed") { transformClipboard(ClipboardTransform.trimmed) }
                Button("Trimmed lowercase") { transformClipboard(ClipboardTransform.lowercaseTrimmed) }
                Divider()
                Button("Title Case") { transformClipboard(ClipboardTransform.titleCase) }
                Button("Sentence case") { transformClipboard(ClipboardTransform.sentenceCase) }
                Divider()
                Button("camelCase") { transformClipboard(ClipboardTransform.camelCase) }
                Button("PascalCase") { transformClipboard(ClipboardTransform.pascalCase) }
                Button("kebab-case (slug)") { transformClipboard(ClipboardTransform.slugify) }
                Button("snake_case") { transformClipboard(ClipboardTransform.snakeCase) }
                Button("CONST_CASE") { transformClipboard(ClipboardTransform.constCase) }
            }
            Menu("Time") {
                Button("→ Epoch (s)") { transformClipboardIfValid(ClipboardTransform.timeToEpochSeconds) }
                Button("→ Epoch (ms)") { transformClipboardIfValid(ClipboardTransform.timeToEpochMilliseconds) }
                Divider()
                Button("→ SQL DateTime (Local)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeLocal) }
                Button("→ SQL DateTime (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToSQLDateTimeUTC) }
                Divider()
                Button("→ RFC3339 (Z)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339Z) }
                Button("→ RFC3339 (+offset)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithOffset) }
                Button("→ RFC3339 (tz abbrev)") { transformClipboardIfValid(ClipboardTransform.timeToRFC3339WithAbbreviation) }
                Divider()
                Button("→ RFC1123 (Local)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123Local) }
                Button("→ RFC1123 (UTC)") { transformClipboardIfValid(ClipboardTransform.timeToRFC1123UTC) }
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
            Menu("URLs") {
                Section("Extract") {
                    Button("Host (Domain)") { transformClipboardIfValid(ClipboardTransform.urlExtractHostIfValid) }
                    Button("Host[:Port]") { transformClipboardIfValid(ClipboardTransform.urlExtractHostPortIfValid) }
                    Button("Port") { transformClipboardIfValid(ClipboardTransform.urlExtractPortIfValid) }
                    Button("Path") { transformClipboardIfValid(ClipboardTransform.urlExtractPathIfValid) }
                    Button("Params") { transformClipboardIfValid(ClipboardTransform.urlExtractQueryIfValid) }
                    Button("Hash") { transformClipboardIfValid(ClipboardTransform.urlExtractFragmentIfValid) }
                }
                Divider()
                Button("Strip URL Params") { transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid) }
                Button("URL-encode") { transformClipboard(ClipboardTransform.urlEncode) }
                Button("URL-decode") { transformClipboard(ClipboardTransform.urlDecode) }
            }
            Menu("Encode & Hash") {
                Section("Base64") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64Encode) }
                    Button("Decode") { transformClipboard(ClipboardTransform.base64Decode) }
                }
                Section("Base64 URL-Safe") {
                    Button("Encode") { transformClipboard(ClipboardTransform.base64URLEncode) }
                    Button("Decode") { transformClipboard(ClipboardTransform.base64URLDecode) }
                }
                Divider()
                Button("JWT Decode") { transformClipboardIfValid(ClipboardTransform.jwtDecode) }
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
            Menu("Multi-line") {
                Button("Sort Lines") { transformClipboard(ClipboardTransform.sortLines) }
                Button("Deduplicate Lines") { transformClipboard(ClipboardTransform.deduplicateLines) }
                Button("Sort + Dedupe Lines") { transformClipboard(ClipboardTransform.sortAndDeduplicateLines) }
                Button("Remove Empty Lines") { transformClipboard(ClipboardTransform.removeEmptyLines) }
                Button("Reverse Lines") { transformClipboard(ClipboardTransform.reverseLines) }
                Button("Shuffle Lines") { transformClipboard(ClipboardTransform.shuffleLines) }
                Divider()
                Button("Indent Lines") { transformClipboard(ClipboardTransform.indentLines) }
                Button("Un-indent Lines") { transformClipboard(ClipboardTransform.unindentLines) }
                Button("Trim Lines") { transformClipboard(ClipboardTransform.trimLines) }
                // TODO:
                // Add "Remove First Char / Line"
                // Add "Remove Last Char / Line"
                Divider()
                Button("CRLF → LF (strip \\r)") { transformClipboard(ClipboardTransform.windowsNewlinesToUnix) }
            }
            Menu("JSON & YAML") {
                Section("JSON") {
                    Button("Prettify") { transformClipboard(ClipboardTransform.jsonPrettify) }
                    Button("Minify") { transformClipboard(ClipboardTransform.jsonMinify) }
                    Button("Sort Keys") { transformClipboard(ClipboardTransform.jsonSortKeys) }
                    Button("Strip Nulls") { transformClipboard(ClipboardTransform.jsonStripNulls) }
                    Button("Strip Empty Strings") { transformClipboard(ClipboardTransform.jsonStripEmptyStrings) }
                    Button("Top-Level Keys") { transformClipboard(ClipboardTransform.jsonTopLevelKeys) }
                    Button("All Keys") { transformClipboard(ClipboardTransform.jsonAllKeys) }
                    Button("Array → CSV") { transformClipboardIfValid(ClipboardTransform.jsonArrayToCsv) }
                    Button("→ YAML") { transformClipboardIfValid(ClipboardTransform.jsonToYaml) }
                }
                Divider()
                Section("YAML") {
                    Button("Prettify") { transformClipboard(ClipboardTransform.yamlPrettify) }
                    Button("Minify") { transformClipboard(ClipboardTransform.yamlMinify) }
                    Button("→ JSON") { transformClipboardIfValid(ClipboardTransform.yamlToJson) }
                }
            }
            Menu("CSV") {
                Section("CSV") {
                    Button("→ JSON (typed)") { transformClipboardIfValid(ClipboardTransform.csvToJson) }
                    Button("→ JSON (strings)") { transformClipboardIfValid(ClipboardTransform.csvToJsonStrings) }
                }
                Divider()
                Section("Tab/Pipe-Separated") {
                    Button("CSV → TSV") { transformClipboard(ClipboardTransform.csvToTsv) }
                    Button("CSV → PSV") { transformClipboard(ClipboardTransform.csvToPsv) }
                    Button("TSV → CSV") { transformClipboardIfValid(ClipboardTransform.tsvToCsv) }
                    Button("PSV → CSV") { transformClipboardIfValid(ClipboardTransform.psvToCsv) }
                }
            }
            Menu("Database CLI") {
                Section("mysql") {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.mysqlCliTableToJson) }
                }
                Divider()
                Section("psql") {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.psqlCliTableToJson) }
                }
                Divider()
                Section("sqlite3") {
                    Button("Table → CSV") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToCsv) }
                    Button("Table → JSON") { transformClipboardIfValid(ClipboardTransform.sqlite3TableToJson) }
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
        Menu("Set Clipboard Data") {
            Menu("Time") {
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
            Menu("Symbol") {
                Menu("Typography") {
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
        }
        Divider()
        Button("New Snippet") {
            editorStore.editingSnippet = nil
            editorStore.initialBody = nil
            editorStore.analyzeSessionId = nil
            editorStore.editorWindowTitle = "Snippet Editor"
            openWindow(id: "editor")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        Button("New Snippet From Clipboard", action: quickSaveFromClipboard)
        Divider()
        if displayedSnippets.isEmpty {
            Text("No snippets yet")
        } else {
            ForEach(displayedSnippets) { snippet in
                Menu(snippetMenuTitle(for: snippet)) {
                    Button("Copy to Clipboard") { copyToClipboard(snippet) }
                    if hasURL(snippet.body) {
                        Button("Open URL") { openURL(from: snippet.body) }
                    }
                    Button("Edit") {
                        editorStore.editingSnippet = snippet
                        editorStore.editorWindowTitle = "Snippet Editor"
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
        }
        Divider()
        Toggle("Mute Sounds", isOn: $muteSounds)
        Button("About Clipboard Envy") {
            openWindow(id: "about")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.title == "About Clipboard Envy" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        }
        Button("Quit Clipboard Envy") {
            NSApp.terminate(nil)
        }
        .onAppear {
            snippetsStore.refresh()
        }
    }

    // MARK: - Actions

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

    private func transformClipboard(_ transform: (String) -> String) {
        ClipboardTransform.apply(transform, muted: muteSounds)
    }

    private func transformClipboardIfValid(_ transform: (String) -> String?) {
        ClipboardTransform.applyIfValid(transform, muted: muteSounds)
    }

    private func transformClipboardIfValid(_ transform: (String) throws -> String) {
        ClipboardTransform.applyIfValid(transform, muted: muteSounds)
    }

    private func setClipboardToEpochSeconds() {
        ClipboardSet.setAndNotify(ClipboardSet.epochSeconds(), muted: muteSounds)
    }
    private func setClipboardToEpochMilliseconds() {
        ClipboardSet.setAndNotify(ClipboardSet.epochMilliseconds(), muted: muteSounds)
    }
    private func setClipboardToSQLDateTimeLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.sqlDateTimeLocal(), muted: muteSounds)
    }
    private func setClipboardToSQLDateTimeUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.sqlDateTimeUTC(), muted: muteSounds)
    }
    private func setClipboardToRFC3339Z() {
        ClipboardSet.setAndNotify(ClipboardSet.rfc3339Z(), muted: muteSounds)
    }
    private func setClipboardToRFC3339WithOffset() {
        ClipboardSet.setAndNotify(ClipboardSet.rfc3339WithOffset(), muted: muteSounds)
    }
    private func setClipboardToRFC3339WithAbbreviation() {
        ClipboardSet.setAndNotify(ClipboardSet.rfc3339WithAbbreviation(), muted: muteSounds)
    }
    private func setClipboardToRFC1123Local() {
        ClipboardSet.setAndNotify(ClipboardSet.rfc1123Local(), muted: muteSounds)
    }
    private func setClipboardToRFC1123UTC() {
        ClipboardSet.setAndNotify(ClipboardSet.rfc1123UTC(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDHHmmssLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddHHmmssLocal(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDHHmmssUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddHHmmssUTC(), muted: muteSounds)
    }
    private func setClipboardToYYMMDDHHmmssLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.yyMMddHHmmssLocal(), muted: muteSounds)
    }
    private func setClipboardToYYMMDDHHmmssUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.yyMMddHHmmssUTC(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddLocal(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddUTC(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDHHLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddHHLocal(), muted: muteSounds)
    }
    private func setClipboardToYYYYMMDDHHUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.yyyyMMddHHUTC(), muted: muteSounds)
    }
    private func setClipboardToYYMMDDLocal() {
        ClipboardSet.setAndNotify(ClipboardSet.yyMMddLocal(), muted: muteSounds)
    }
    private func setClipboardToYYMMDDUTC() {
        ClipboardSet.setAndNotify(ClipboardSet.yyMMddUTC(), muted: muteSounds)
    }
    private func setClipboardToRandomUUID() {
        ClipboardSet.setAndNotify(ClipboardSet.randomUUID(), muted: muteSounds)
    }
    private func setClipboardToRandomUUIDLowercase() {
        ClipboardSet.setAndNotify(ClipboardSet.randomUUIDLowercase(), muted: muteSounds)
    }

    private func setClipboardToRandomHex(byteCount: Int) {
        if let s = ClipboardSet.randomHexString(byteCount: byteCount) {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomULID() {
        if let s = ClipboardSet.randomULID() {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomNanoID() {
        if let s = ClipboardSet.randomNanoID() {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomVeryComplexPassword() {
        if let s = ClipboardSet.randomVeryComplexPassword() {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomComplexPassword() {
        if let s = ClipboardSet.randomComplexPassword() {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }
    private func setClipboardToRandomAlphanumericPassword() {
        if let s = ClipboardSet.randomAlphanumericPassword() {
            ClipboardSet.setAndNotify(s, muted: muteSounds)
        } else {
            ClipboardSound.playClipboardError(muted: muteSounds)
        }
    }

    private func setClipboardTo(_ string: String) {
        ClipboardSet.setAndNotify(string, muted: muteSounds)
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

    private func snippetMenuTitle(for snippet: Snippet) -> String {
        if let t = snippet.title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return truncated(normalizedForMenu(t), limit: 40)
        }
        return truncated(normalizedForMenu(snippet.body), limit: 40)
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
