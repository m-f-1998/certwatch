import Foundation

enum AppMetadata {
    static let supportURL = URL(string: "https://matthewfrankland.co.uk/certwatch")!
    static let privacyPolicyURL = URL(string: "https://matthewfrankland.co.uk/certwatch/privacy")!
    static let feedbackEmail = "certwatch@matthewfrankland.co.uk"

    static var versionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.1"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    static var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "CertWatch Feedback")]
        return components.url ?? URL(string: "mailto:\(feedbackEmail)")!
    }
}
