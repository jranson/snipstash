import Foundation

extension ClipboardTransform {
    // MARK: - JSON

    nonisolated static func jsonPrettify(_ s: String) -> String {
        let sanitized = sanitizeCommentedJSONInput(s)
        guard let data = sanitized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let out = String(data: pretty, encoding: .utf8) else { return s }
        return out
    }

    nonisolated static func jsonMinify(_ s: String) -> String {
        let sanitized = sanitizeCommentedJSONInput(s)
        guard let data = sanitized.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let compact = try? JSONSerialization.data(withJSONObject: json),
              let out = String(data: compact, encoding: .utf8) else { return s }
        return out
    }

    nonisolated static func jsonSortKeys(_ s: String) -> String {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return s }
        let newlineCount = trimmed.components(separatedBy: "\n").count - 1
        if newlineCount == 0 {
            guard let compact = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
                  let out = String(data: compact, encoding: .utf8) else { return s }
            return out
        } else {
            guard let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                  let out = String(data: pretty, encoding: .utf8) else { return s }
            return out
        }
    }

    nonisolated static func jsonStripNulls(_ s: String) -> String {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return s }
        let stripped = stripJSONNulls(from: json)
        return serializeJSONLikeInput(stripped, trimmedInput: trimmed, fallback: s)
    }

    nonisolated static func jsonStripEmptyStrings(_ s: String) -> String {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let stripped = stripJSONEmptyStrings(from: json) else { return s }
        return serializeJSONLikeInput(stripped, trimmedInput: trimmed, fallback: s)
    }

    nonisolated static func jsonTopLevelKeys(_ s: String) -> String {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return s }

        var keys = Set<String>()
        if let dictionary = json as? [String: Any] {
            keys.formUnion(dictionary.keys)
        } else if let array = json as? [Any] {
            for element in array {
                if let dictionary = element as? [String: Any] {
                    keys.formUnion(dictionary.keys)
                }
            }
        } else {
            return s
        }
        guard !keys.isEmpty else { return s }
        return keys.sorted().joined(separator: "\n")
    }

    nonisolated static func jsonAllKeys(_ s: String) -> String {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return s }

        var keys = Set<String>()
        collectJSONKeys(from: json, into: &keys)
        guard !keys.isEmpty else { return s }
        return keys.sorted().joined(separator: "\n")
    }

    /// Returns true when the given string is a JSON array whose elements are all
    /// simple literals (strings / numbers / booleans / null), with no objects or
    /// nested arrays. Used by the menu UI to decide when to hide JSON→CSV hints
    /// for arrays like ["Commas", "Spaces", "Tabs"] unless Option is held.
    nonisolated static func isSimpleLiteralJsonArray(_ s: String) -> Bool {
        let trimmed = sanitizeCommentedJSONInput(s).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data),
              let array = json as? [Any] else {
            return false
        }

        return array.allSatisfy { element in
            switch element {
            case is String, is NSNumber, is NSNull:
                return true
            case is [Any], is [String: Any]:
                return false
            default:
                return false
            }
        }
    }

    private nonisolated static func stripJSONNulls(from value: Any) -> Any {
        if value is NSNull {
            return NSNull()
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                let strippedValue = stripJSONNulls(from: entry.value)
                if !(strippedValue is NSNull) {
                    result[entry.key] = strippedValue
                }
            }
        }
        if let array = value as? [Any] {
            return array.compactMap { element -> Any? in
                let strippedValue = stripJSONNulls(from: element)
                return strippedValue is NSNull ? nil : strippedValue
            }
        }
        return value
    }

    private nonisolated static func stripJSONEmptyStrings(from value: Any) -> Any? {
        if let string = value as? String {
            return string.isEmpty ? nil : string
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                if let strippedValue = stripJSONEmptyStrings(from: entry.value) {
                    result[entry.key] = strippedValue
                }
            }
        }
        if let array = value as? [Any] {
            return array.compactMap { stripJSONEmptyStrings(from: $0) }
        }
        return value
    }

    private nonisolated static func collectJSONKeys(from value: Any, into keys: inout Set<String>) {
        if let dictionary = value as? [String: Any] {
            keys.formUnion(dictionary.keys)
            for nestedValue in dictionary.values {
                collectJSONKeys(from: nestedValue, into: &keys)
            }
        } else if let array = value as? [Any] {
            for element in array {
                collectJSONKeys(from: element, into: &keys)
            }
        }
    }

    private nonisolated static func serializeJSONLikeInput(_ value: Any, trimmedInput: String, fallback: String) -> String {
        let newlineCount = trimmedInput.components(separatedBy: "\n").count - 1
        let options: JSONSerialization.WritingOptions = newlineCount == 0 ? [.sortedKeys] : [.prettyPrinted, .sortedKeys]
        guard JSONSerialization.isValidJSONObject(value),
              let outputData = try? JSONSerialization.data(withJSONObject: value, options: options),
              let out = String(data: outputData, encoding: .utf8) else { return fallback }
        return out
    }

    nonisolated static func sanitizeCommentedJSONInput(_ s: String) -> String {
        s
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmedLeading = line.drop { $0 == " " || $0 == "\t" }
                return !trimmedLeading.hasPrefix("//")
            }
            .map(String.init)
            .joined(separator: "\n")
    }
}
