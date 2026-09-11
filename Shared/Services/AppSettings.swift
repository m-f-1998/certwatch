import Foundation

enum AppSettings {
    static let appGroupID = "group.com.matthewfrankland.certwatch"
    static let proProductID = "com.mfrankland.certwatch.pro"
    static let freeEndpointLimit = 5
    static let defaultThresholds = [30, 14, 7, 1]
    static let freeThresholds = [30]

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    static var isProUnlocked: Bool {
        get { defaults.bool(forKey: Keys.isProUnlocked) }
        set { defaults.set(newValue, forKey: Keys.isProUnlocked) }
    }

    static var notificationThresholds: [Int] {
        get {
            if let stored = defaults.array(forKey: Keys.notificationThresholds) as? [Int], !stored.isEmpty {
                return stored
            }
            return isProUnlocked ? defaultThresholds : freeThresholds
        }
        set {
            defaults.set(newValue.sorted(by: >), forKey: Keys.notificationThresholds)
        }
    }

    static var defaultCheckPort: Int {
        get {
            let value = defaults.integer(forKey: Keys.defaultCheckPort)
            return value == 0 ? 443 : value
        }
        set {
            defaults.set(newValue, forKey: Keys.defaultCheckPort)
        }
    }

    static var backgroundRefreshEnabled: Bool {
        get { defaults.bool(forKey: Keys.backgroundRefreshEnabled) }
        set { defaults.set(newValue, forKey: Keys.backgroundRefreshEnabled) }
    }

    static var endpointLimit: Int {
        isProUnlocked ? Int.max : freeEndpointLimit
    }

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isProUnlocked = "isProUnlocked"
        static let notificationThresholds = "notificationThresholds"
        static let defaultCheckPort = "defaultCheckPort"
        static let backgroundRefreshEnabled = "backgroundRefreshEnabled"
    }
}
