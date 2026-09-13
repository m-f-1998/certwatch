import Foundation
import SwiftData
import UserNotifications

enum NotificationRescheduleService {
    @MainActor
    static func rescheduleAll() async {
        do {
            let container = try ModelContainerFactory.makeContainer()
            let context = ModelContext(container)
            let store = EndpointStore(modelContext: context)
            try await store.rescheduleAllNotifications()
        } catch {
            // Endpoints remain monitored even if notification scheduling fails.
        }
    }

    /// Reschedules alerts when notification permission is newly granted, e.g. after enabling in iOS Settings.
    @MainActor
    @discardableResult
    static func rescheduleIfAuthorizationGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let current = settings.authorizationStatus
        let previous = AppSettings.lastNotificationAuthorizationStatus

        defer { AppSettings.lastNotificationAuthorizationStatus = current }

        let isAuthorized = current == .authorized || current == .provisional
        guard isAuthorized else { return false }

        let wasUnauthorized = previous != .authorized && previous != .provisional
        guard wasUnauthorized else { return false }

        await rescheduleAll()
        return true
    }

    @MainActor
    static func syncWithStoredAuthorization() async {
        _ = await rescheduleIfAuthorizationGranted()
    }
}
