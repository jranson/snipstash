import Foundation

extension ClipboardTransform {
    // MARK: - URL

    nonisolated static func stripUrlParams(_ s: String) -> String {
        s.components(separatedBy: .newlines).map { line in
            line.split(separator: " ").map { word -> String in
                var str = String(word)
                if let q = str.firstIndex(of: "?") { str = String(str[..<q]) }
                if let h = str.firstIndex(of: "#") { str = String(str[..<h]) }
                return str
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    nonisolated static func stripUrlParamsIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        let firstWord = firstLine.split(separator: " ").first.map(String.init) ?? firstLine
        guard URL(string: String(firstWord)) != nil else { return nil }
        let result = stripUrlParams(s)
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return result
    }

    nonisolated static func urlEncode(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    nonisolated static func urlDecode(_ s: String) -> String {
        // Treat '+' as space for typical x-www-form-urlencoded bodies before percent-decoding.
        let plusAsSpace = s.replacingOccurrences(of: "+", with: " ")
        return plusAsSpace.removingPercentEncoding ?? plusAsSpace
    }

    nonisolated static func urlExtractHostIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        return host
    }

    nonisolated static func urlExtractHostPortIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let host = url.host, !host.isEmpty else { return nil }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }

    nonisolated static func urlExtractPortIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let port = url.port else { return nil }
        return String(port)
    }

    nonisolated static func urlExtractPathIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), !url.path.isEmpty else { return nil }
        return url.path
    }

    nonisolated static func urlExtractFragmentIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let fragment = url.fragment, !fragment.isEmpty else { return nil }
        return fragment
    }

    nonisolated static func urlExtractQueryIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let query = url.query, !query.isEmpty else { return nil }
        return query
    }

    nonisolated static func urlExtractUsernameIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let user = url.user, !user.isEmpty else { return nil }
        return user
    }

    nonisolated static func urlExtractCredentialsIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), let user = url.user, !user.isEmpty else { return nil }
        if let password = url.password, !password.isEmpty {
            return "\(user):\(password)"
        }
        return user
    }

    nonisolated static func urlStripCredentialsIfValid(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
        guard let url = URL(string: candidate), url.user != nil else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.user = nil
        components?.password = nil
        return components?.string
    }
}
