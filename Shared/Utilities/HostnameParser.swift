import Darwin
import Foundation

struct ParsedHost: Equatable, Sendable {
    let hostname: String
    let port: Int
}

enum HostnameParser {
    static let defaultPort = 443
    static let maxPort = 65_535

    static func parse(_ input: String, defaultPort: Int = defaultPort) -> Result<ParsedHost, ParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        if trimmed.contains("://") {
            return parseURL(trimmed, defaultPort: defaultPort)
        }

        switch parseHostPort(trimmed, defaultPort: defaultPort) {
        case .success(let hostPort):
            return .success(hostPort)
        case .failure(let error):
            return .failure(error)
        case nil:
            break
        }

        return .failure(.invalidHost)
    }

    enum ParseError: Error, Equatable, LocalizedError {
        case empty
        case invalidURL
        case invalidHost
        case invalidPort
        case unsupportedScheme(String)

        var errorDescription: String? {
            switch self {
            case .empty:
                return "Enter a hostname or URL."
            case .invalidURL:
                return "Enter a valid URL such as api.example.com or https://host:8443."
            case .invalidHost:
                return "Invalid hostname or IP address."
            case .invalidPort:
                return "Port must be between 1 and 65535."
            case .unsupportedScheme(let scheme):
                return "Use http:// or https:// URLs. “\(scheme)://” is not supported."
            }
        }
    }

    private static let supportedSchemes: Set<String> = ["http", "https"]

    private static func parseURL(_ input: String, defaultPort: Int) -> Result<ParsedHost, ParseError> {
        guard let components = URLComponents(string: input) else {
            return .failure(.invalidURL)
        }

        if let scheme = components.scheme?.lowercased(), !supportedSchemes.contains(scheme) {
            return .failure(.unsupportedScheme(scheme))
        }

        if components.user != nil || components.password != nil {
            return .failure(.invalidURL)
        }

        guard let host = components.host, !host.isEmpty else {
            return .failure(.invalidURL)
        }

        let port = components.port ?? defaultPort
        guard isValidPort(port) else { return .failure(.invalidPort) }
        guard isValidHostname(host) else { return .failure(.invalidHost) }
        return .success(ParsedHost(hostname: normalizeHost(host), port: port))
    }

    private static func parseHostPort(_ input: String, defaultPort: Int) -> Result<ParsedHost, ParseError>? {
        if input.hasPrefix("[") {
            return parseBracketedIPv6(input, defaultPort: defaultPort)
        }

        let parts = input.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 1 {
            let host = String(parts[0])
            guard isValidHostname(host) else { return nil }
            return .success(ParsedHost(hostname: normalizeHost(host), port: defaultPort))
        }

        if parts.count == 2 {
            guard let port = Int(parts[1]) else { return nil }
            guard isValidPort(port) else { return .failure(.invalidPort) }
            let host = String(parts[0])
            guard isValidHostname(host) else { return .failure(.invalidHost) }
            return .success(ParsedHost(hostname: normalizeHost(host), port: port))
        }

        return nil
    }

    private static func parseBracketedIPv6(_ input: String, defaultPort: Int) -> Result<ParsedHost, ParseError>? {
        guard let closing = input.firstIndex(of: "]") else { return nil }
        let host = String(input[input.index(after: input.startIndex)..<closing])
        guard isValidHostname(host) else { return nil }

        let remainder = input[input.index(after: closing)...]
        if remainder.isEmpty {
            return .success(ParsedHost(hostname: host, port: defaultPort))
        }
        guard remainder.first == ":", let port = Int(remainder.dropFirst()) else {
            return nil
        }
        guard isValidPort(port) else { return .failure(.invalidPort) }
        return .success(ParsedHost(hostname: host, port: port))
    }

    static func isValidPort(_ port: Int) -> Bool {
        (1...maxPort).contains(port)
    }

    static func isValidHostname(_ host: String) -> Bool {
        let normalized = normalizeHost(host)
        guard !normalized.isEmpty, normalized.count <= 253 else { return false }

        if normalized.contains(":") {
            return isValidIPv6(normalized)
        }

        if normalized.allSatisfy({ $0.isNumber || $0 == "." }) {
            return isValidIPv4(normalized)
        }

        let labels = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        return labels.allSatisfy { label in
            guard (1...63).contains(label.count) else { return false }
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
            guard String(label).unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
            guard let first = label.first, let last = label.last else { return false }
            return first != "-" && last != "-"
        }
    }

    private static func normalizeHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let value = Int(part), (0...255).contains(value) else { return false }
            return part == Substring(String(value))
        }
    }

    private static func isValidIPv6(_ host: String) -> Bool {
        var addr = in6_addr()
        return host.withCString { inet_pton(AF_INET6, $0, &addr) } == 1
    }
}
