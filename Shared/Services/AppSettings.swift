import Foundation
import UserNotifications

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

    static func unlockPro() {
        guard !isProUnlocked else { return }
        isProUnlocked = true
        migrateNotificationThresholdsForProUnlock()
    }

    private static func migrateNotificationThresholdsForProUnlock() {
        let stored = defaults.array(forKey: Keys.notificationThresholds) as? [Int]
        if stored == nil || stored == freeThresholds {
            notificationThresholds = defaultThresholds
        }
    }

    static var notificationThresholds: [Int] {
        get {
            if let stored = defaults.array(forKey: Keys.notificationThresholds) as? [Int], !stored.isEmpty {
                if isProUnlocked {
                    return normalizedProThresholds(stored)
                }
                return stored
            }
            return isProUnlocked ? defaultThresholds : freeThresholds
        }
        set {
            let sanitized = newValue.filter { $0 > 0 }
            if isProUnlocked {
                defaults.set(normalizedProThresholds(sanitized), forKey: Keys.notificationThresholds)
            } else {
                let unique = Array(Set(sanitized)).sorted(by: >)
                defaults.set(unique, forKey: Keys.notificationThresholds)
            }
        }
    }

    static func normalizedProThresholds(_ stored: [Int]) -> [Int] {
        (0..<defaultThresholds.count).map { index in
            index < stored.count ? stored[index] : defaultThresholds[index]
        }
    }

    static func uniqueThresholdsForScheduling(_ thresholds: [Int]) -> [Int] {
        Array(Set(thresholds.filter { $0 > 0 })).sorted(by: >)
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

    static var lastNotificationAuthorizationStatus: UNAuthorizationStatus? {
        get {
            guard let raw = defaults.string(forKey: Keys.lastNotificationAuthorizationStatus) else {
                return nil
            }
            return authorizationStatus(from: raw)
        }
        set {
            if let newValue {
                defaults.set(authorizationStatusKey(for: newValue), forKey: Keys.lastNotificationAuthorizationStatus)
            } else {
                defaults.removeObject(forKey: Keys.lastNotificationAuthorizationStatus)
            }
        }
    }

    private static func authorizationStatusKey(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .authorized: "authorized"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown"
        }
    }

    private static func authorizationStatus(from key: String) -> UNAuthorizationStatus? {
        switch key {
        case "notDetermined": .notDetermined
        case "denied": .denied
        case "authorized": .authorized
        case "provisional": .provisional
        case "ephemeral": .ephemeral
        default: nil
        }
    }

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isProUnlocked = "isProUnlocked"
        static let notificationThresholds = "notificationThresholds"
        static let defaultCheckPort = "defaultCheckPort"
        static let backgroundRefreshEnabled = "backgroundRefreshEnabled"
        static let lastNotificationAuthorizationStatus = "lastNotificationAuthorizationStatus"
    }
}
