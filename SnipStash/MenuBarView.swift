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
            Snippet(body: "Have you stood+stretched this past hour?", title: nil, timestamp: Date(timeInterval: 2, since: t0)),
            Snippet(body: "HAVE YOU?", title: nil, timestamp: Date(timeInterval: 3, since: t0)),
            Snippet(body: "John's PubKey", title: nil, timestamp: Date(timeInterval: 4, since: t0)),
            Snippet(body: "Interviewer Questions: AWS Lambda", title: nil, timestamp: Date(timeInterval: 5, since: t0)),
            Snippet(body: "https://github.com/my-org/my-repo/issues", title: nil, timestamp: Date(timeInterval: 6, since: t0)),
        ]
    }()
    #endif

    var body: some View {
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
        Button("Capture Snippet From Clipboard", action: quickSaveFromClipboard)
        Button("Analyze Clipboard Data") {
            if let str = ClipboardIO.readString() {
                editorStore.initialBody = str
                editorStore.analyzeSessionId = UUID()
                editorStore.editingSnippet = nil
                editorStore.editorWindowTitle = "Clipboard Analysis"
                openWindow(id: "editor")
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        Menu("Transform Clipboard Data") {
            Menu("Casing & Spacing") {
                Button("Lowercase") { transformClipboard(ClipboardTransform.lowercase) }
                Button("Uppercase") { transformClipboard(ClipboardTransform.uppercase) }
                Button("Trimmed") { transformClipboard(ClipboardTransform.trimmed) }
                Button("LCase + Trimmed") { transformClipboard(ClipboardTransform.lowercaseTrimmed) }
            }
            Menu("URLs") {
                Button("Host") { transformClipboardIfValid(ClipboardTransform.urlExtractHostIfValid) }
                Button("Path") { transformClipboardIfValid(ClipboardTransform.urlExtractPathIfValid) }
                Button("Params") { transformClipboardIfValid(ClipboardTransform.urlExtractQueryIfValid) }
                Button("Hash") { transformClipboardIfValid(ClipboardTransform.urlExtractFragmentIfValid) }
                Button("Strip URL Params") { transformClipboardIfValid(ClipboardTransform.stripUrlParamsIfValid) }
                Button("URL-encode") { transformClipboard(ClipboardTransform.urlEncode) }
                Button("URL-decode") { transformClipboard(ClipboardTransform.urlDecode) }
                Button("Slugify") { transformClipboard(ClipboardTransform.slugify) }
            }
            Menu("Encode & Hash") {
                Button("Base64 Encode") { transformClipboard(ClipboardTransform.base64Encode) }
                Button("Base64 Decode") { transformClipboard(ClipboardTransform.base64Decode) }
                Button("MD5 Checksum") { transformClipboard(ClipboardTransform.md5Checksum) }
                Button("SHA1 Checksum") { transformClipboard(ClipboardTransform.sha1Checksum) }
                Button("SHA256 Checksum") { transformClipboard(ClipboardTransform.sha256Checksum) }
            }
            Menu("Structured Data") {
                Button("JSON Prettify") { transformClipboard(ClipboardTransform.jsonPrettify) }
                Button("JSON Minify") { transformClipboard(ClipboardTransform.jsonMinify) }
                Button("CSV → TSV") { transformClipboard(ClipboardTransform.csvToTsv) }
            }
            Menu("Multi-line Data") {
                Button("Sort Lines") { transformClipboard(ClipboardTransform.sortLines) }
                Button("Deduplicate Lines") { transformClipboard(ClipboardTransform.deduplicateLines) }
                Button("Sort + Dedupe Lines") { transformClipboard(ClipboardTransform.sortAndDeduplicateLines) }
                Button("Reverse Lines") { transformClipboard(ClipboardTransform.reverseLines) }
                Divider()
                Button("CRLF → LF (strip \\r)") { transformClipboard(ClipboardTransform.windowsNewlinesToUnix) }
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
                #if DEBUG
                Divider()
                Button(useDemoSnippets ? "Turn Demo Menu Off" : "Turn Demo Menu On") {
                    demoMenuEnabled.toggle()
                }
                #endif
            }
        }
        Menu("Set Clipboard Data") {
            Button("Current Epoch Time (s)") { setClipboardToEpochSeconds() }
            Button("Current Epoch Time (ms)") { setClipboardToEpochMilliseconds() }
            Button("Current SQL DateTime (Local)") { setClipboardToSQLDateTimeLocal() }
            Button("Current SQL DateTime (UTC)") { setClipboardToSQLDateTimeUTC() }
            Button("Current RFC3339 Time (Z)") { setClipboardToRFC3339Z() }
            Button("Current RFC3339 (+offset)") { setClipboardToRFC3339WithOffset() }
            Button("Current RFC3339 (tz abbrev)") { setClipboardToRFC3339WithAbbreviation() }
            Divider()
            Button("Random UUID (Lowercase)") { setClipboardToRandomUUIDLowercase() }
            Button("Random UUID (Uppercase)") { setClipboardToRandomUUID() }
        }
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
        Button("About SnipStash") {
            openWindow(id: "about")
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let w = NSApp.windows.first(where: { $0.title == "About SnipStash" }) {
                    if w.isMiniaturized {
                        w.deminiaturize(nil)
                    }
                    w.makeKeyAndOrderFront(nil)
                }
            }
        }
        Button("Quit SnipStash") {
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
    private func setClipboardToRandomUUID() {
        ClipboardSet.setAndNotify(ClipboardSet.randomUUID(), muted: muteSounds)
    }
    private func setClipboardToRandomUUIDLowercase() {
        ClipboardSet.setAndNotify(ClipboardSet.randomUUIDLowercase(), muted: muteSounds)
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
