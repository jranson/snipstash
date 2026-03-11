import SwiftUI
import SwiftData

struct SnippetEditorView: View {
    let snippet: Snippet?
    let onSave: (String, String?) -> Void
    let onSaveAndSetClipboard: ((String, String?) -> Void)?
    let onCancel: () -> Void

    @State private var text: String
    @State private var title: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case body, title
    }

    private var characterCount: Int { text.count }
    private var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    private var lineCount: Int {
        let lines = text.components(separatedBy: .newlines)
        if text.hasSuffix("\n") { return lines.count }
        return max(1, lines.count)
    }
    private var emdashCount: Int {
        text.unicodeScalars.filter { $0 == "\u{2014}" }.count
    }

    init(snippet: Snippet?, onSave: @escaping (String, String?) -> Void, onSaveAndSetClipboard: ((String, String?) -> Void)? = nil, onCancel: @escaping () -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        self.onSaveAndSetClipboard = onSaveAndSetClipboard
        self.onCancel = onCancel
        _text = State(initialValue: snippet?.body ?? "")
        _title = State(initialValue: snippet?.title ?? "")
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: .title)
                .onKeyPress(.tab) {
                    focusedField = .body
                    return .handled
                }
            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundStyle(Color(nsColor: .textColor))
                .frame(maxWidth: .infinity, minHeight: 400)
                .border(Color.secondary.opacity(0.3))
                .background(Color(NSColor.textBackgroundColor))
                .focused($focusedField, equals: .body)
                .onKeyPress(.tab) {
                    focusedField = .title
                    return .handled
                }
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 16) {
                    Text("Chars: \(characterCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Words: \(wordCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Lines: \(lineCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Em dashes: \(emdashCount)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.escape)
                    .buttonHoverBrightness()
                Button("Save Snippet") {
                    save()
                }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonHoverBrightness()
                if let onSaveAndSetClipboard {
                    Button("Save Snippet + Set Clipboard") {
                        onSaveAndSetClipboard(text, trimmedTitle())
                    }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .buttonHoverBrightness()
                }
            }
        }
        .padding()
        .frame(minWidth: 780)
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onAppear {
            focusedField = .body
        }
    }

    private func trimmedTitle() -> String? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func save() {
        onSave(text, trimmedTitle())
    }
}

// MARK: - Hover brightness for buttons (macOS)
private struct ButtonHoverBrightness: ViewModifier {
    @State private var isHovering = false
    func body(content: Content) -> some View {
        content
            .brightness(isHovering ? 0.1 : 0)
            .onHover { isHovering = $0 }
    }
}
private extension View {
    func buttonHoverBrightness() -> some View {
        modifier(ButtonHoverBrightness())
    }
}

#Preview {
    SnippetEditorView(snippet: nil, onSave: { _, _ in }, onSaveAndSetClipboard: nil, onCancel: { })
        .modelContainer(for: Snippet.self, inMemory: true)
}
