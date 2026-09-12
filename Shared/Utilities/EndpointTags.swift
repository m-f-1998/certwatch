import Foundation

enum EndpointTags {
    static let maxLength = 32
    static let suggested = [
        "Production",
        "Staging",
        "Development",
        "Personal",
        "Internal",
        "Client"
    ]

    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    static func remember(_ tag: String) {
        guard let normalized = normalize(tag) else { return }
        unhide(normalized)
        var tags = remembered
        tags.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        tags.insert(normalized, at: 0)
        remembered = Array(tags.prefix(24))
    }

    static func removeFromCatalog(_ tag: String) {
        guard let normalized = normalize(tag) else { return }
        forget(normalized)
        hide(normalized)
    }

    static func isHidden(_ tag: String) -> Bool {
        guard let normalized = normalize(tag) else { return false }
        return hidden.contains(normalized)
    }

    static func pickerOptions(from endpoints: [MonitoredEndpoint]) -> [String] {
        let inUse = Set(endpoints.compactMap { normalize($0.tag ?? "") })
        var options = inUse
            .filter { !isHidden($0) }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        var seen = Set(options)
        for tag in remembered where !seen.contains(tag) && !isHidden(tag) {
            options.append(tag)
            seen.insert(tag)
        }
        for suggestion in suggested where !seen.contains(suggestion) && !isHidden(suggestion) {
            options.append(suggestion)
            seen.insert(suggestion)
        }
        return options
    }

    static func displayOptions(base: [String], including additional: String...) -> [String] {
        var seen = Set<String>()
        var options: [String] = []
        for raw in additional + base {
            guard let tag = normalize(raw), !seen.contains(tag), !isHidden(tag) else { continue }
            seen.insert(tag)
            options.append(tag)
        }
        return options
    }

    private static func forget(_ tag: String) {
        guard let normalized = normalize(tag) else { return }
        remembered.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
    }

    private static func hide(_ tag: String) {
        guard let normalized = normalize(tag) else { return }
        var tags = hidden
        guard !tags.contains(normalized) else { return }
        tags.append(normalized)
        hidden = tags
    }

    private static func unhide(_ tag: String) {
        guard let normalized = normalize(tag) else { return }
        hidden.removeAll { $0 == normalized }
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppSettings.appGroupID) ?? .standard
    }

    private static var remembered: [String] {
        get { defaults.stringArray(forKey: "rememberedTags") ?? [] }
        set { defaults.set(newValue, forKey: "rememberedTags") }
    }

    private static var hidden: [String] {
        get { defaults.stringArray(forKey: "hiddenTags") ?? [] }
        set { defaults.set(newValue, forKey: "hiddenTags") }
    }

    static func filterOptions(from endpoints: [MonitoredEndpoint]) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for endpoint in endpoints {
            guard let tag = normalize(endpoint.tag ?? "") else { continue }
            counts[tag, default: 0] += 1
        }
        return counts
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (name: $0.key, count: $0.value) }
    }
}
