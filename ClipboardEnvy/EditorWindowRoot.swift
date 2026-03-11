import SwiftUI
import SwiftData
import AppKit

struct EditorWindowRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var editorStore: EditorStore
    @EnvironmentObject private var snippetsStore: SnippetsStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false
    @State private var escapeMonitor: Any? = nil

    var body: some View {
        Group {
            if let snippet = editorStore.editingSnippet {
                SnippetEditorView(snippet: snippet, onSave: { body, title in
                    saveSnippet(snippet: snippet, body: body, title: title)
                    dismiss()
                }, onSaveAndSetClipboard: { body, title in
                    saveSnippet(snippet: snippet, body: body, title: title)
                    setClipboardAndNotify(body)
                    dismiss()
                }, onCancel: {
                    dismiss()
                })
                .id(snippet.id)
            } else {
                SnippetEditorView(snippet: nil, onSave: { body, title in
                    let new = Snippet(body: body, title: title, timestamp: Date())
                    modelContext.insert(new)
                    snippetsStore.refresh()
                    dismiss()
                }, onSaveAndSetClipboard: { body, title in
                    let new = Snippet(body: body, title: title, timestamp: Date())
                    modelContext.insert(new)
                    snippetsStore.refresh()
                    setClipboardAndNotify(body)
                    dismiss()
                }, onCancel: {
                    dismiss()
                })
                .id("new")
            }
        }
        .onAppear {
            setWindowTitle()
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event } // Escape
                let t = NSApp.keyWindow?.title ?? ""
                guard t == "Snippet Editor" else { return event }
                Task { @MainActor in dismiss() }
                return nil
            }
        }
        .onDisappear {
            if let m = escapeMonitor {
                NSEvent.removeMonitor(m)
                escapeMonitor = nil
            }
        }
    }

    private func saveSnippet(snippet: Snippet, body: String, title: String?) {
        snippet.body = body
        snippet.title = title
        snippetsStore.refresh()
    }

    private func setClipboardAndNotify(_ string: String) {
        _ = ClipboardIO.writeString(string)
        ClipboardSound.playClipboardWritten(muted: muteSounds)
    }

    private func setWindowTitle() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.title = "Snippet Editor"
            NSApp.mainWindow?.title = "Snippet Editor"
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Snippet.self, configurations: .init(isStoredInMemoryOnly: true))
    EditorWindowRoot()
        .environmentObject(EditorStore())
        .environmentObject(SnippetsStore(container: container))
        .modelContainer(container)
}
