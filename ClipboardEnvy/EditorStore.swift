import SwiftUI
import Combine

final class EditorStore: ObservableObject {
    @Published var editingSnippet: Snippet? = nil
}
