//
//  SnipStashApp.swift
//  SnipStash
//

import SwiftUI
import SwiftData

@main
struct SnipStashApp: App {
    @StateObject private var editorStore = EditorStore()
    @StateObject private var snippetsStore: SnippetsStore

    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Snippet.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        _snippetsStore = StateObject(wrappedValue: SnippetsStore(container: Self.sharedModelContainer))
    }

    var body: some Scene {
        MenuBarExtra(content: {
            MenuBarView()
                .environmentObject(editorStore)
                .environmentObject(snippetsStore)
        }, label: {
            Image(nsImage: SnippetMenubarIcon.makeTemplateImage())
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        })
        .modelContainer(Self.sharedModelContainer)

        Window(editorStore.editorWindowTitle, id: "editor") {
            EditorWindowRoot()
                .environmentObject(editorStore)
                .environmentObject(snippetsStore)
        }
        .modelContainer(Self.sharedModelContainer)
        .defaultSize(width: 560, height: 420)

        Window("About SnipStash", id: "about") {
            AboutSnipStashView()
        }
        .defaultSize(width: 520, height: 540)
        .windowResizability(.contentSize)
    }
}
