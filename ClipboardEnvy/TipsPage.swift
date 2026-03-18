//
//  TipsPage.swift
//  Clipboard Envy
//

import SwiftUI
import AppKit

struct TipsClipboardEnvyView: View {
    private static let windowID = "tips-clipboard-envy"
    @State private var escapeMonitor: Any? = nil
    @State private var isGitHubLinkHovered = false
    @State private var isAppStoreLinkHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Image("AppIconTransparent")
                        .resizable()
                        .frame(width: 36, height: 36)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(BuildInfo.appName) Tips")
                            .font(.system(size: 24))
                            .fontWeight(.semibold)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    tipRow(
                        title: "Auto-paste after updating clipboard",
                        detail: "Hold ⇧ Shift when clicking any “Set/Transform Clipboard Text” action or Snippet > “Copy to Clipboard” to automatically paste (⌘V) into the active app."
                    )
                    tipRow(
                        title: "Auto-copy selection to clipboard before transforming",
                        detail: "Hold ⌥ Option when clicking a “Transform Clipboard Text” action to autmatically copy first (⌘C), then transform the clipboard."
                    )
                    tipRow(
                        title: "Auto-copy and auto-paste when transforming",
                        detail: "Hold ⌥ Option + ⇧ Shift while clicking a “Transform Clipboard Text” action to automatically copy (⌘C), transform, then paste (⌘V)."
                    )
                }
                .padding(.top, 8)
            }
            Spacer()
            HStack(spacing: 12) {
                Spacer()
                Button("Close") {
                    closeTipsWindow()
                }
                .font(.system(size: 15))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(width: 570, height: 560)
        .onKeyPress(.escape) {
            closeTipsWindow()
            return .handled
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event } // Escape
                guard NSApp.keyWindow?.identifier?.rawValue == Self.windowID else { return event }
                Task { @MainActor in closeTipsWindow() }
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

    private func closeTipsWindow() {
        NSApp.windows.first { $0.identifier?.rawValue == Self.windowID }?.close()
    }

    @ViewBuilder
    private func tipRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("✨ \(title)")
                    .font(.system(size: 15, weight: .semibold))
            } icon: {}
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .secondarySystemFill).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        )
    }
}

#Preview {
    TipsClipboardEnvyView()
        .frame(width: 570, height: 560)
}

