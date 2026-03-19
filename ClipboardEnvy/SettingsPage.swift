//
//  SettingsPage.swift
//  Clipboard Envy
//

import SwiftUI
import AppKit

// MARK: - Private Models

private struct DictEntry: Identifiable, Equatable {
    var id = UUID()
    var label: String
    var value: String
}

private struct DictSectionConfig {
    enum ValueEditorKind {
        case single
        case swap
        case wrapper
    }

    let key: String
    let description: String
    let valueHeader: String
    let valuePlaceholder: String
    let valueEditorKind: ValueEditorKind
    let labelHeader: String = "Menu Label"
}

private enum SettingsSection: String, CaseIterable, Identifiable, Hashable {
    case general      = "General"
    case soundEffects = "Sound Effects"
    case removeLines  = "Remove Lines Menu"
    case splitJoin    = "Split / Join Menus"
    case textRemoves  = "Remove Text Menu"
    case textSwaps    = "Replace Text Menu"
    case lineWrappers = "Wrap / Unwrap Lines Menu"
    case awkPatterns  = "Awk Lines Menu"
    case argon2       = "Argon2"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general:      return "gearshape"
        case .soundEffects: return "speaker"
        case .argon2:       return "lock.shield"
        case .removeLines:  return "list.number"
        case .splitJoin:    return "scissors"
        case .textRemoves:  return "eraser"
        case .textSwaps:    return "arrow.left.arrow.right"
        case .lineWrappers: return "text.alignleft"
        case .awkPatterns:  return "terminal"
        }
    }

    var dictConfig: DictSectionConfig? {
        switch self {
        case .splitJoin:
            return DictSectionConfig(
                key: "SplitJoinDelimiters",
                description: "Custom delimiters for Multi-line → Join / Split menu items. Each entry adds a new delimiter choice to both Join and Split sub-menus.",
                valueHeader: "Delimiter",
                valuePlaceholder: "\\t, |, etc.",
                valueEditorKind: .single
            )
        case .textRemoves:
            return DictSectionConfig(
                key: "TextRemoves",
                description: "Custom substrings for the Remove menu items. Each entry adds a one-click option to strip that substring from the clipboard.",
                valueHeader: "Substring to Remove",
                valuePlaceholder: "e.g., [draft], \t, ;, etc. ",
                valueEditorKind: .single
            )
        case .textSwaps:
            return DictSectionConfig(
                key: "TextSwaps",
                description: "Find & replace pairs for the Replace menu items. Value format: from -> to (whitespace around the arrow is ignored).",
                valueHeader: "from -> to",
                valuePlaceholder: "e.g.  . -> ,  or  http -> https",
                valueEditorKind: .swap
            )
        case .lineWrappers:
            return DictSectionConfig(
                key: "TextLineWrappers",
                description: "Prefix/suffix pairs for Multi-line → Wrap / Unwrap Lines. Value format: prefix|suffix (use a literal | as the separator).",
                valueHeader: "prefix|suffix",
                valuePlaceholder: "e.g.  <|>  or  \"|\"|\"\"",
                valueEditorKind: .wrapper
            )
        case .awkPatterns:
            return DictSectionConfig(
                key: "AwkPrintPatterns",
                description: "Custom awk-style print patterns for Multi-line → Awk. Supports optional -F 'X' delimiter and a {print $1 $2 …} block.",
                valueHeader: "Awk Command",
                valuePlaceholder: "-F ':' '{print $1\" \"$3}'",
                valueEditorKind: .single
            )
        default:
            return nil
        }
    }
}

// MARK: - Flow Layout (for chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, containerWidth: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, containerWidth: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(subviews: Subviews, containerWidth: CGFloat) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > containerWidth, x > 0 {
                x = 0; y += rowH + spacing; rowH = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return (CGSize(width: containerWidth, height: y + rowH), origins)
    }
}

// MARK: - Window Configurator (hides title bar text, bleeds sidebar to top)

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Settings Panel (theme-specific bordered container)

private struct SettingsPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.05)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Section Title Helper

private struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 22, weight: .semibold))
    }
}

private struct SystemSoundOption: Identifiable {
    let id: String
    let osName: String
}

private struct ClipboardSoundRow: View {
    let title: String
    @Binding var selectedSoundID: String
    let volumeBinding: Binding<Double>
    let volumeValue: Int
    let options: [SystemSoundOption]
    let onPlay: () -> Void

    @State private var isHoveringPlay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                HStack(spacing: 16) {
                    Picker(title, selection: $selectedSoundID) {
                        ForEach(options) { option in
                            Text(option.osName).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(
                                (isHoveringPlay ? Color(nsColor: .linkColor) : Color.primary)
                                    .opacity(isHoveringPlay ? 1 : 0.65)
                            )
                            .padding(6)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        (isHoveringPlay ? Color(nsColor: .linkColor) : Color.primary)
                                            .opacity(isHoveringPlay ? 1 : 0.65),
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                    .onHover { hovering in
                        isHoveringPlay = hovering
                    }
                    .help("Play selected sound at current volume")
                }
            }

            Divider()

            HStack {
                Text("Volume")
                    .font(.system(size: 13))
                Spacer()
                DiscreteVolumeSlider(value: volumeBinding, range: 0...100)
                    .frame(maxWidth: 175)
                Text("\(volumeValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .center)
            }
        }
    }
}

private struct DiscreteVolumeSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: value,
            minValue: range.lowerBound,
            maxValue: range.upperBound,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        return slider
    }

    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.minValue = range.lowerBound
        nsView.maxValue = range.upperBound
        if nsView.doubleValue != value {
            nsView.doubleValue = value
        }
    }

    final class Coordinator: NSObject {
        private var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc
        func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue.rounded()
        }
    }
}

// MARK: - Main Settings View

struct SettingsClipboardEnvyView: View {
    private static let windowTitle = "\(BuildInfo.appName) Settings"
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: SettingsSection? = .general
    @State private var escapeMonitor: Any? = nil
    
    private var selectedSectionBinding: Binding<SettingsSection?> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                // Avoid nil selection (which can leave the detail pane blank).
                selectedSection = newValue ?? selectedSection ?? .soundEffects
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Sidebar
                VStack(spacing: 0) {
                    // Header — sits in the safe-area gap left by the transparent title bar
                    HStack(spacing: 10) {
                        Image("AppIconTransparent")
                            .resizable()
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(BuildInfo.appName)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            Text("Settings")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider()
                        .opacity(0.45)
                        .padding(.horizontal, 10)

                    List(SettingsSection.allCases, selection: selectedSectionBinding) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .font(.system(size: 13.5, weight: .medium))
                            .tag(section)
                            .padding(.vertical, 2)
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                .frame(width: 240)
                .background(
                    colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.05)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.white.opacity(1), lineWidth: 1)
                )
                .padding(.leading, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Detail content
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .quaternarySystemFill))
                    Group {
                        if let section = selectedSection {
                            if let config = section.dictConfig {
                                DictSettingsView(
                                    title: section.rawValue,
                                    description: config.description,
                                    key: config.key,
                                    labelHeader: config.labelHeader,
                                    valueHeader: config.valueHeader,
                                    valuePlaceholder: config.valuePlaceholder,
                                    valueEditorKind: config.valueEditorKind
                                )
                            } else {
                                switch section {
                                case .general:
                                    GeneralSettingsView()
                                case .soundEffects:
                                    SoundEffectsSettingsView()
                                case .argon2:
                                    Argon2SettingsView()
                                case .removeLines:
                                    RemoveLinesSettingsView()
                                case .splitJoin, .textRemoves, .textSwaps, .lineWrappers, .awkPatterns:
                                    EmptyView()
                                }
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .id(selectedSection?.id ?? SettingsSection.soundEffects.id)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .padding(.trailing, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer
            Divider()
            HStack {
                Spacer()
                Button("Close") { closeSettingsWindow() }
                    .font(.system(size: 15))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 780, height: 548)
        .background(WindowConfigurator())
        .onKeyPress(.escape) {
            closeSettingsWindow()
            return .handled
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event }
                guard NSApp.keyWindow?.title == Self.windowTitle else { return event }
                Task { @MainActor in closeSettingsWindow() }
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

    private func closeSettingsWindow() {
        NSApp.windows.first { $0.title == Self.windowTitle }?.close()
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    private static let recentSnippetsMenuCountRange: ClosedRange<Int> = 0...20
    private static let snippetMenuLabelMaxCharsRange: ClosedRange<Int> = 10...64

    @AppStorage("recentSnippetsMenuCount") private var recentSnippetsMenuCount = 10
    @AppStorage("snippetMenuLabelMaxChars") private var snippetMenuLabelMaxChars = 36

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "General")

                SettingsCard {
                    VStack(spacing: 0) {
                        Argon2Row(
                            label: "Recent Snippets in Menu",
                            description: "Number of recent snippets shown at the top-level. Default: 10",
                            value: $recentSnippetsMenuCount,
                            range: Self.recentSnippetsMenuCountRange,
                            step: 1
                        )
                        Divider().padding(.leading, 16)
                        Argon2Row(
                            label: "Snippet Menu Label Max Length",
                            description: "Max characters before truncation with an ellipsis. Default: 36",
                            value: $snippetMenuLabelMaxChars,
                            range: Self.snippetMenuLabelMaxCharsRange,
                            step: 1
                        )
                    }
                }

                Spacer()
                Spacer()
                Spacer()
                Spacer()
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    tipRow(
                        title: "Power User Tip  —  Auto-Copy & Auto-Paste",
                        detail: "Try pressing ⌥ Option, ⇧ Shift, or ⌥ Option + ⇧ Shift while the \(BuildInfo.appName) menu is open for some cool power-ups!",
                        bullet: "💡"
                    )
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: recentSnippetsMenuCount) { _, v in
            let clamped = min(max(v, Self.recentSnippetsMenuCountRange.lowerBound), Self.recentSnippetsMenuCountRange.upperBound)
            if clamped != v {
                recentSnippetsMenuCount = clamped
            }
        }
        .onChange(of: snippetMenuLabelMaxChars) { _, v in
            let clamped = min(max(v, Self.snippetMenuLabelMaxCharsRange.lowerBound), Self.snippetMenuLabelMaxCharsRange.upperBound)
            if clamped != v {
                snippetMenuLabelMaxChars = clamped
            }
        }
    }

    @ViewBuilder
    private func tipRow(title: String, detail: String, bullet: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bullet.isEmpty ? title : "\(bullet) \(title)")
                .font(.system(size: 14.5, weight: .semibold))
            Text(detail)
                .font(.system(size: 14.5))
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .secondarySystemFill).opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct SoundEffectsSettingsView: View {
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false
    @AppStorage("clipboardWrittenSound") private var clipboardWrittenSound = "Frog"
    @AppStorage("clipboardWrittenVolume") private var clipboardWrittenVolume = 25
    @AppStorage("clipboardErrorSound") private var clipboardErrorSound = "Tink"
    @AppStorage("clipboardErrorVolume") private var clipboardErrorVolume = 40

    /// Internal NSSound names mapped to current macOS UI names where they differ.
    private let soundOptions: [SystemSoundOption] = [
        .init(id: "Tink", osName: "Boop"),
        .init(id: "Blow", osName: "Breeze"),
        .init(id: "Pop", osName: "Bubble"),
        .init(id: "Glass", osName: "Crystal"),
        .init(id: "Funk", osName: "Funky"),
        .init(id: "Hero", osName: "Heroine"),
        .init(id: "Frog", osName: "Jump"),
        .init(id: "Basso", osName: "Mezzo"),
        .init(id: "Bottle", osName: "Pebble"),
        .init(id: "Purr", osName: "Pluck"),
        .init(id: "Morse", osName: "Pong"),
        .init(id: "Ping", osName: "Sonar"),
        .init(id: "Sosumi", osName: "Sonumi"),
        .init(id: "Submarine", osName: "Submerge"),
    ]

    private var writtenVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(clipboardWrittenVolume) },
            set: { clipboardWrittenVolume = Int($0.rounded()) }
        )
    }

    private var errorVolumeBinding: Binding<Double> {
        Binding(
            get: { Double(clipboardErrorVolume) },
            set: { clipboardErrorVolume = Int($0.rounded()) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "Sound Effects")

                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsPanel {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Mute Sound Effects")
                                        .font(.system(size: 14))
                                    Text("Silence audio feedback on clipboard operations.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $muteSounds)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }

                        SettingsPanel {
                            ClipboardSoundRow(
                                title: "Clipboard Written Sound",
                                selectedSoundID: $clipboardWrittenSound,
                                volumeBinding: writtenVolumeBinding,
                                volumeValue: clipboardWrittenVolume,
                                options: soundOptions,
                                onPlay: {
                                    Task { @MainActor in
                                        ClipboardSound.playClipboardWritten(muted: muteSounds)
                                    }
                                }
                            )
                        }
                        .padding(.bottom, 12)

                        SettingsPanel {
                            ClipboardSoundRow(
                                title: "Clipboard Error Sound",
                                selectedSoundID: $clipboardErrorSound,
                                volumeBinding: errorVolumeBinding,
                                volumeValue: clipboardErrorVolume,
                                options: soundOptions,
                                onPlay: {
                                    Task { @MainActor in
                                        ClipboardSound.playClipboardError(muted: muteSounds)
                                    }
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Argon2id Settings

private struct Argon2SettingsView: View {
    @State private var memoryKiB: Int = 65535
    @State private var iterations: Int = 3
    @State private var parallelism: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "Argon2id Hash")

                Text("Parameters for Encode & Hash → Argon2id Hash. Higher values increase security but require more time and memory.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SettingsCard {
                    VStack(spacing: 0) {
                        Argon2Row(
                            label: "Memory (KiB)",
                            description: "Memory cost. Default: 65,535",
                            value: $memoryKiB,
                            range: 1024...524288,
                            step: 1024
                        )
                        Divider().padding(.leading, 16)
                        Argon2Row(
                            label: "Iterations",
                            description: "Time cost (iterations). Default: 3",
                            value: $iterations,
                            range: 1...100,
                            step: 1
                        )
                        Divider().padding(.leading, 16)
                        Argon2Row(
                            label: "Parallelism",
                            description: "Parallelism (lanes). Default: 1",
                            value: $parallelism,
                            range: 1...64,
                            step: 1
                        )
                    }
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            let ud = UserDefaults.standard
            memoryKiB  = ud.integer(forKey: "Argon2MemoryKiB")
            iterations = ud.integer(forKey: "Argon2Iterations")
            parallelism = ud.integer(forKey: "Argon2Parallelism")
        }
        .onChange(of: memoryKiB)   { _, v in UserDefaults.standard.set(v, forKey: "Argon2MemoryKiB") }
        .onChange(of: iterations)  { _, v in UserDefaults.standard.set(v, forKey: "Argon2Iterations") }
        .onChange(of: parallelism) { _, v in UserDefaults.standard.set(v, forKey: "Argon2Parallelism") }
    }
}

private struct Argon2Row: View {
    let label: String
    let description: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.system(size: 14))
                Text(description).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            TextField("", value: $value, format: .number)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Remove Lines Settings

private struct RemoveLinesSettingsView: View {
    @State private var values: [Int] = []
    @State private var newValueText: String = ""
    @State private var inputError: Bool = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: "Remove Lines")

                Text("The line counts shown in Multi-line → Remove / Head / Tail sub-menus.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        if values.isEmpty {
                            Text("No values configured.")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 6)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(values, id: \.self) { v in
                                    valueChip(v)
                                }
                            }
                        }

                        Divider()

                        HStack(spacing: 8) {
                            TextField("Add a number…", text: $newValueText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                                .focused($isInputFocused)
                                .onSubmit { addValue() }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(inputError ? Color.red.opacity(0.7) : Color.clear, lineWidth: 1.5)
                                )
                            Button("Add") { addValue() }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .disabled(newValueText.trimmingCharacters(in: .whitespaces).isEmpty)
                            if inputError {
                                Text("Enter a positive integer")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.red)
                                    .transition(.opacity)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { loadValues() }
        .animation(.easeInOut(duration: 0.15), value: inputError)
    }

    private func valueChip(_ v: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(v)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .padding(.leading, 10)
                .padding(.vertical, 5)
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    values.removeAll { $0 == v }
                    save()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(Color(nsColor: .linkColor).opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color(nsColor: .linkColor).opacity(0.3), lineWidth: 1))
    }

    private func loadValues() {
        let key = "RemoveLinesValues"
        if let stored = UserDefaults.standard.array(forKey: key) {
            values = stored.compactMap { item -> Int? in
                if let n = item as? Int { return n }
                if let s = item as? String { return Int(s) }
                return nil
            }.sorted()
        } else {
            values = [1, 2, 5, 10, 25, 50]
        }
    }

    private func save() {
        UserDefaults.standard.set(values, forKey: "RemoveLinesValues")
    }

    private func addValue() {
        let trimmed = newValueText.trimmingCharacters(in: .whitespaces)
        guard let n = Int(trimmed), n > 0 else {
            inputError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { inputError = false }
            return
        }
        inputError = false
        if !values.contains(n) {
            withAnimation(.spring(duration: 0.2)) {
                values.append(n)
                values.sort()
                save()
            }
        }
        newValueText = ""
    }
}

// MARK: - Dict Settings (reusable for all dictionary-backed defaults)

private struct DictSettingsView: View {
    let title: String
    let description: String
    let key: String
    let labelHeader: String
    let valueHeader: String
    let valuePlaceholder: String
    let valueEditorKind: DictSectionConfig.ValueEditorKind

    @State private var entries: [DictEntry] = []
    @State private var newLabel: String = ""
    @State private var newValue: String = ""
    @State private var newSecondaryValue: String = ""

    private var canAdd: Bool {
        let hasLabel = !newLabel.trimmingCharacters(in: .whitespaces).isEmpty
        let hasPrimary = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
        let hasSecondary = !newSecondaryValue.trimmingCharacters(in: .whitespaces).isEmpty
        switch valueEditorKind {
        case .single:
            return hasLabel && hasPrimary
        case .swap, .wrapper:
            return hasLabel && hasPrimary && hasSecondary
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionTitle(title: title)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SettingsCard {
                    VStack(alignment: .leading, spacing: 0) {
                        if !entries.isEmpty {
                            // Column headers
                            HStack(spacing: 0) {
                                Text(labelHeader)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 180, alignment: .leading)
                                columnSeparator
                                if valueEditorKind == .single {
                                    Text(valueHeader)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                } else {
                                    Text(primaryHeader)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                    columnSeparator
                                    Text(secondaryHeader)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 8)
                                }
                                Color.clear.frame(width: 30)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                            Divider()

                            ForEach($entries) { $entry in
                                VStack(spacing: 0) {
                                    HStack(spacing: 0) {
                                        TextField(labelHeader, text: $entry.label)
                                            .textFieldStyle(.plain)
                                            .frame(width: 180)
                                            .onChange(of: entry.label) { _, _ in save() }
                                        columnSeparator
                                        if valueEditorKind == .single {
                                            TextField(valuePlaceholder, text: $entry.value)
                                                .textFieldStyle(.plain)
                                                .frame(maxWidth: .infinity)
                                                .padding(.leading, 8)
                                                .onChange(of: entry.value) { _, _ in save() }
                                        } else {
                                            TextField(primaryPlaceholder, text: primaryBinding(for: $entry))
                                                .textFieldStyle(.plain)
                                                .frame(maxWidth: .infinity)
                                                .padding(.leading, 8)
                                            columnSeparator
                                            TextField(secondaryPlaceholder, text: secondaryBinding(for: $entry))
                                                .textFieldStyle(.plain)
                                                .frame(maxWidth: .infinity)
                                                .padding(.leading, 8)
                                        }
                                        Button {
                                            withAnimation(.spring(duration: 0.2)) {
                                                entries.removeAll { $0.id == entry.id }
                                                save()
                                            }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 16))
                                                .foregroundStyle(.red.opacity(0.75))
                                        }
                                        .buttonStyle(.plain)
                                        .frame(width: 30)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    if entry.id != entries.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }

                            Divider()
                        }

                        // Add new entry row
                        HStack(spacing: 0) {
                            TextField("Menu Label", text: $newLabel)
                                .textFieldStyle(.plain)
                                .frame(width: 150)
                                .onSubmit { if canAdd { addEntry() } }
                            columnSeparator
                            if valueEditorKind == .single {
                                TextField(valuePlaceholder, text: $newValue)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .padding(.leading, 8)
                                    .onSubmit { if canAdd { addEntry() } }
                            } else {
                                TextField(primaryPlaceholder, text: $newValue)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .padding(.leading, 8)
                                    .onSubmit { if canAdd { addEntry() } }
                                columnSeparator
                                TextField(secondaryPlaceholder, text: $newSecondaryValue)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                    .padding(.leading, 8)
                                    .onSubmit { if canAdd { addEntry() } }
                            }
                            Button("Add") { addEntry() }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                                .disabled(!canAdd)
                                .frame(width: 46)
                                .padding(.leading, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            entries.isEmpty
                                ? Color.clear
                                : Color(nsColor: .controlBackgroundColor).opacity(0.4)
                        )
                    }
                }

                if entries.isEmpty {
                    Text("No entries yet. Add one above and it will appear in the menu immediately.")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { loadEntries() }
        .onChange(of: key) { _, _ in
            // When this reusable view is repointed to a different defaults key,
            // reload local state so entries don't bleed between sections.
            newLabel = ""
            newValue = ""
            newSecondaryValue = ""
            loadEntries()
        }
    }

    private var primaryHeader: String {
        switch valueEditorKind {
        case .swap: return "From"
        case .wrapper: return "Start"
        case .single: return valueHeader
        }
    }

    private var secondaryHeader: String {
        switch valueEditorKind {
        case .swap: return "To"
        case .wrapper: return "End"
        case .single: return ""
        }
    }

    private var primaryPlaceholder: String {
        switch valueEditorKind {
        case .swap: return "From"
        case .wrapper: return "Start"
        case .single: return valuePlaceholder
        }
    }

    private var secondaryPlaceholder: String {
        switch valueEditorKind {
        case .swap: return "To"
        case .wrapper: return "End"
        case .single: return ""
        }
    }

    private var columnSeparator: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func deserializeValue(_ serialized: String) -> (primary: String, secondary: String) {
        switch valueEditorKind {
        case .single:
            return (serialized, "")
        case .swap:
            guard let range = serialized.range(of: "->") else {
                return (serialized.trimmingCharacters(in: .whitespaces), "")
            }
            let from = String(serialized[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let to = String(serialized[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (from, to)
        case .wrapper:
            let parts = serialized.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                return (serialized, "")
            }
            return (String(parts[0]), String(parts[1]))
        }
    }

    private func serializeValue(primary: String, secondary: String) -> String {
        switch valueEditorKind {
        case .single:
            return primary
        case .swap:
            let from = primary.trimmingCharacters(in: .whitespaces)
            let to = secondary.trimmingCharacters(in: .whitespaces)
            return "\(from) -> \(to)"
        case .wrapper:
            return "\(primary)|\(secondary)"
        }
    }

    private func primaryBinding(for entry: Binding<DictEntry>) -> Binding<String> {
        Binding(
            get: {
                deserializeValue(entry.wrappedValue.value).primary
            },
            set: { newPrimary in
                let current = deserializeValue(entry.wrappedValue.value)
                entry.wrappedValue.value = serializeValue(primary: newPrimary, secondary: current.secondary)
                save()
            }
        )
    }

    private func secondaryBinding(for entry: Binding<DictEntry>) -> Binding<String> {
        Binding(
            get: {
                deserializeValue(entry.wrappedValue.value).secondary
            },
            set: { newSecondary in
                let current = deserializeValue(entry.wrappedValue.value)
                entry.wrappedValue.value = serializeValue(primary: current.primary, secondary: newSecondary)
                save()
            }
        )
    }

    private func loadEntries() {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: String] else {
            entries = []
            return
        }
        entries = dict.map { DictEntry(label: $0.key, value: $0.value) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func save() {
        var dict: [String: String] = [:]
        for entry in entries where !entry.label.isEmpty {
            dict[entry.label] = entry.value
        }
        if dict.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(dict, forKey: key)
        }
    }

    private func addEntry() {
        let trimLabel = newLabel.trimmingCharacters(in: .whitespaces)
        let trimValue = newValue.trimmingCharacters(in: .whitespaces)
        let trimSecondaryValue = newSecondaryValue.trimmingCharacters(in: .whitespaces)
        let serialized: String
        switch valueEditorKind {
        case .single:
            guard !trimLabel.isEmpty, !trimValue.isEmpty else { return }
            serialized = trimValue
        case .swap, .wrapper:
            guard !trimLabel.isEmpty, !trimValue.isEmpty, !trimSecondaryValue.isEmpty else { return }
            serialized = serializeValue(primary: trimValue, secondary: trimSecondaryValue)
        }
        withAnimation(.spring(duration: 0.2)) {
            entries.append(DictEntry(label: trimLabel, value: serialized))
            save()
        }
        newLabel = ""
        newValue = ""
        newSecondaryValue = ""
    }
}

// MARK: - Preview

#Preview {
    SettingsClipboardEnvyView()
}
