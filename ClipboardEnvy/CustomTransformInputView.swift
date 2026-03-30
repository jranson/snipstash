import SwiftUI

struct CustomTransformInputView: View {
    let title: String
    let fields: [CustomTransformStore.FieldDefinition]
    let onSubmit: ([String]) -> Void
    let onCancel: () -> Void

    @State private var values: [String]
    @FocusState private var focusedIndex: Int?

    init(
        title: String,
        fields: [CustomTransformStore.FieldDefinition],
        onSubmit: @escaping ([String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.fields = fields
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        _values = State(initialValue: Array(repeating: "", count: fields.count))
    }

    private var canSubmit: Bool {
        !values.isEmpty && !values[0].trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)

            ForEach(fields.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fields[i].label)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    TextField(fields[i].placeholder, text: $values[i])
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .focused($focusedIndex, equals: i)
                        .onSubmit {
                            if i < fields.count - 1 {
                                focusedIndex = i + 1
                            } else if canSubmit {
                                submit()
                            }
                        }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .buttonHoverEffect()
                Button("Apply") { submit() }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!canSubmit)
                    .buttonHoverEffect()
            }
        }
        .padding(20)
        .frame(minWidth: 380)
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onAppear {
            focusedIndex = 0
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(values)
    }
}

private struct ButtonHoverEffect: ViewModifier {
    @State private var isHovering = false
    func body(content: Content) -> some View {
        content
            .brightness(isHovering ? 0.1 : 0)
            .onHover { isHovering = $0 }
    }
}

private extension View {
    func buttonHoverEffect() -> some View {
        modifier(ButtonHoverEffect())
    }
}

#Preview {
    CustomTransformInputView(
        title: "Replace Text",
        fields: [
            .init(label: "Find", placeholder: "e.g. foo"),
            .init(label: "Replace with", placeholder: "e.g. bar"),
        ],
        onSubmit: { _ in },
        onCancel: { }
    )
}
