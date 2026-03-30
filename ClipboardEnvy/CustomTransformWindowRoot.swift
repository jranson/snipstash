import SwiftUI
import AppKit

struct CustomTransformWindowRoot: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CustomTransformStore
    @AppStorage("muteQuickSaveSounds") private var muteSounds = false

    var body: some View {
        Group {
            if let pending = store.pending {
                CustomTransformInputView(
                    title: pending.title,
                    fields: pending.fields,
                    onSubmit: { values in
                        applyTransform(pending.transform, with: values)
                        dismiss()
                    },
                    onCancel: {
                        dismiss()
                    }
                )
                .id(store.session)
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
    }

    private func applyTransform(
        _ transform: @escaping (String, [String]) -> String,
        with values: [String]
    ) {
        guard let text = ClipboardIO.readString() else {
            ClipboardSound.playClipboardError(muted: muteSounds)
            return
        }
        let result = transform(text, values)
        _ = ClipboardIO.writeString(result)
        ClipboardSound.playClipboardWritten(muted: muteSounds)
    }
}
