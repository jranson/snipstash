//
//  AboutSnipStashView.swift
//  SnipStash
//

import SwiftUI
import AppKit

struct AboutSnipStashView: View {
    private let githubURL = URL(string: "https://github.com/centennial-oss/snipstash")!
    private static let windowTitle = "About SnipStash"
    @State private var escapeMonitor: Any? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image("AppIconTransparent")
                    .resizable()
                    .frame(width: 56, height: 56)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(BuildInfo.appName)
                        .font(.system(size: 30))
                        .fontWeight(.semibold)

                    Text("v" + BuildInfo.version)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }

            Text(BuildInfo.copyright)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Label("SnipStash is 100% private. It does not snoop or collect analytics.", systemImage: "shield")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            Label("SnipStash was vibecoded with Claude, ChatGPT & Cursor Composer.\nIt is completely free and open source for you to enjoy.", systemImage: "heart")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            Link(destination: githubURL) {
                Label("GitHub: centennial-oss/snipstash", systemImage: "arrow.up.right.square")
            }
            .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 2) {
                Label("Build info (copy for support)", systemImage: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text(BuildInfo.copyableBlob)
                    .font(.system(size: 14, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .padding(.leading, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Copy to Clipboard") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(BuildInfo.copyableBlob, forType: .string)
                }
                .font(.system(size: 15))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.leading, 32)
            }

            Label("SnipStash is not a password manager and should not be used to store passwords or other secrets. Use a dedicated password manager like Apple Passwords for sensitive credentials.", systemImage: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Close") {
                    closeAboutWindow()
                }
                .font(.system(size: 15))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .padding(.leading, 10)
        .frame(width: 540, height: 560)
        .onKeyPress(.escape) {
            closeAboutWindow()
            return .handled
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event } // Escape
                guard NSApp.keyWindow?.title == Self.windowTitle else { return event }
                Task { @MainActor in closeAboutWindow() }
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

    private func closeAboutWindow() {
        NSApp.windows.first { $0.title == Self.windowTitle }?.close()
    }
}

#Preview {
    AboutSnipStashView()
        .frame(width: 540, height: 560)
}
