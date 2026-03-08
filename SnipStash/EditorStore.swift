import SwiftUI
import Combine

final class EditorStore: ObservableObject {
    @Published var editingSnippet: Snippet? = nil
    /// When non-nil, the editor opens with this body (e.g. from "Analyze Clipboard") instead of empty.
    @Published var initialBody: String? = nil
    /// Ensures the editor view is recreated when opening "Analyze Clipboard" again with new content.
    @Published var analyzeSessionId: UUID? = nil
    /// Window title: "Clipboard Analysis" in analyze mode, "Snippet Editor" otherwise.
    @Published var editorWindowTitle: String = "Snippet Editor"
}
