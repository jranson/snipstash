import Foundation
import Combine

final class CustomTransformStore: ObservableObject {

    struct FieldDefinition {
        let label: String
        let placeholder: String
    }

    struct PendingTransform {
        let title: String
        let fields: [FieldDefinition]
        let transform: (String, [String]) -> String
    }

    @Published var pending: PendingTransform? = nil
    /// Bumped on each new request so views re-initialize their field state.
    @Published var session: UInt = 0

    func request(
        title: String,
        fields: [FieldDefinition],
        transform: @escaping (String, [String]) -> String
    ) {
        pending = PendingTransform(title: title, fields: fields, transform: transform)
        session += 1
    }

    func clear() {
        pending = nil
    }
}
