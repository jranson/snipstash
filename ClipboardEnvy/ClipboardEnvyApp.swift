//
//  ClipboardEnvyApp.swift
//  Clipboard Envy
//

import SwiftUI
import SwiftData

@main
struct ClipboardEnvyApp: App {
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
        Self.registerArgon2Defaults()
        MenuOpenBridge.install()
    }

    /// Register default Argon2id parameters. Override via:
    ///   defaults write org.centennialoss.snipstash Argon2MemoryKiB 65535
    ///   defaults write org.centennialoss.snipstash Argon2Iterations 3
    ///   defaults write org.centennialoss.snipstash Argon2Parallelism 1
    private static func registerArgon2Defaults() {
        UserDefaults.standard.register(defaults: [
            "Argon2MemoryKiB": 65535,
            "Argon2Iterations": 3,
            "Argon2Parallelism": 1,
        ])
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

        Window("Snippet Editor", id: "editor") {
            EditorWindowRoot()
                .environmentObject(editorStore)
                .environmentObject(snippetsStore)
        }
        .modelContainer(Self.sharedModelContainer)
        .defaultSize(width: 560, height: 420)

        Window("About \(BuildInfo.appName)", id: "about-clipboard-envy") {
            AboutClipboardEnvyView()
        }
        .defaultSize(width: 520, height: 540)
        .windowResizability(.contentSize)

        Window("\(BuildInfo.appName) Settings", id: "settings-clipboard-envy") {
            SettingsClipboardEnvyView()
        }
        .defaultSize(width: 780, height: 548)
        .windowResizability(.contentSize)
    }
}
