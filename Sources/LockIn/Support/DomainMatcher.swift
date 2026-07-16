import Foundation

enum DomainMatcher {
    static func normalizedDomain(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return nil
        }

        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: value),
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        guard var host = components.host?
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        else {
            return nil
        }

        guard host.contains("."), !host.contains("/") else {
            return nil
        }

        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }

        var path = components.percentEncodedPath
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }

        guard path.isEmpty || path.hasPrefix("/") else {
            return nil
        }

        return path.isEmpty || path == "/" ? host : host + path
    }

    static func host(_ host: String, matchesDomain domain: String) -> Bool {
        guard let normalizedHost = normalizedDomain(host),
              let normalizedDomain = normalizedDomain(domain) else {
            return false
        }

        guard !normalizedDomain.contains("/") else {
            return false
        }

        return normalizedHost == normalizedDomain || normalizedHost.hasSuffix("." + normalizedDomain)
    }

    static func url(_ url: URL, matchesDomain domain: String) -> Bool {
        guard let normalizedRule = normalizedDomain(domain),
              let urlHost = url.host,
              let normalizedHost = normalizedDomain(urlHost) else {
            return false
        }

        let ruleParts = normalizedRule.split(separator: "/", maxSplits: 1).map(String.init)
        let ruleHost = ruleParts[0]
        let hostMatches = normalizedHost == ruleHost || normalizedHost.hasSuffix("." + ruleHost)
        guard hostMatches else {
            return false
        }

        guard ruleParts.count == 2 else {
            return true
        }

        let rulePath = "/" + ruleParts[1]
        let urlPath = url.path.isEmpty ? "/" : url.path.lowercased()
        return urlPath == rulePath || urlPath.hasPrefix(rulePath + "/")
    }
}
