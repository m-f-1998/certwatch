import Foundation
import UserNotifications

struct ScheduledAlert: Identifiable, Sendable, Equatable {
    let id: String
    let hostPortLabel: String
    let threshold: Int
    let fireDate: Date?
    let body: String
}

struct NotificationEndpoint: Sendable {
    let id: UUID
    let hostPortLabel: String
    let validUntil: Date?
    let isReachable: Bool

    init(_ endpoint: MonitoredEndpoint) {
        id = endpoint.id
        hostPortLabel = endpoint.hostPortLabel
        validUntil = endpoint.validUntil
        isReachable = endpoint.isReachable
    }
}

protocol NotificationScheduling: Sendable {
    func requestAuthorizationIfNeeded() async
    func scheduleNotifications(for endpoint: NotificationEndpoint) async throws
    func removeNotifications(for endpointID: UUID) async
    func rescheduleAll(_ endpoints: [NotificationEndpoint]) async throws
    func removeOrphanedNotifications(validEndpointIDs: Set<UUID>) async
    func certWatchPendingCount() async -> Int
    func pendingAlerts() async -> [ScheduledAlert]
    func scheduleTestNotification(after seconds: TimeInterval) async throws
}

struct NotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let thresholdsProvider: @Sendable () -> [Int]
    private let nowProvider: @Sendable () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        thresholdsProvider: @escaping @Sendable () -> [Int] = { AppSettings.notificationThresholds },
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.center = center
        self.thresholdsProvider = thresholdsProvider
        self.nowProvider = nowProvider
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func scheduleNotifications(for endpoint: NotificationEndpoint) async throws {
        await removeNotifications(for: endpoint.id)
        guard endpoint.isReachable, let validUntil = endpoint.validUntil else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let now = nowProvider()
        let daysRemaining = ExpiryBadgeStyle.daysRemaining(until: validUntil, from: now)
        let thresholds = Self.applicableThresholds(
            AppSettings.uniqueThresholdsForScheduling(thresholdsProvider()),
            daysRemaining: daysRemaining,
            validUntil: validUntil,
            now: now
        )

        for threshold in thresholds {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -threshold, to: validUntil),
                  fireDate > now else {
                continue
            }

            let body = Self.notificationBody(
                hostPortLabel: endpoint.hostPortLabel,
                validUntil: validUntil,
                threshold: threshold
            )

            let content = UNMutableNotificationContent()
            content.title = "Certificate expiring soon"
            content.body = body
            content.sound = .default
            content.userInfo = [
                "hostPortLabel": endpoint.hostPortLabel,
                "threshold": threshold,
                "validUntil": validUntil.timeIntervalSince1970
            ]

            let trigger = Self.trigger(for: fireDate, now: now)
            let identifier = Self.notificationID(endpointID: endpoint.id, threshold: threshold)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
        }

        await pruneNotifications(
            for: endpoint.id,
            allowedThresholds: Set(thresholds),
            now: now
        )
    }

    func removeNotifications(for endpointID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("\(endpointID.uuidString)-") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func rescheduleAll(_ endpoints: [NotificationEndpoint]) async throws {
        for endpoint in endpoints {
            await removeNotifications(for: endpoint.id)
        }
        for endpoint in endpoints {
            try await scheduleNotifications(for: endpoint)
        }
    }

    func removeOrphanedNotifications(validEndpointIDs: Set<UUID>) async {
        let pending = await center.pendingNotificationRequests()
        let orphanedIDs = pending.compactMap { request -> String? in
            guard let parsed = Self.parseNotificationID(request.identifier) else { return nil }
            return validEndpointIDs.contains(parsed.endpointID) ? nil : request.identifier
        }
        guard !orphanedIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: orphanedIDs)
    }

    func certWatchPendingCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.filter { Self.parseNotificationID($0.identifier) != nil }.count
    }

    func pendingAlerts() async -> [ScheduledAlert] {
        let pending = await center.pendingNotificationRequests()
        return pending.compactMap { request -> ScheduledAlert? in
            guard let parsed = Self.parseNotificationID(request.identifier) else { return nil }
            let hostPortLabel = request.content.userInfo["hostPortLabel"] as? String ?? "Certificate"
            return ScheduledAlert(
                id: request.identifier,
                hostPortLabel: hostPortLabel,
                threshold: parsed.threshold,
                fireDate: Self.fireDate(for: request.trigger),
                body: request.content.body
            )
        }
        .sorted { ($0.fireDate ?? .distantFuture) < ($1.fireDate ?? .distantFuture) }
    }

    func scheduleTestNotification(after seconds: TimeInterval) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw NotificationSchedulerError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "CertWatch test alert"
        content.body = "Notifications are working. Real expiry alerts fire on the schedule below."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.testNotificationID,
            content: content,
            trigger: trigger
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.testNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [Self.testNotificationID])
        try await center.add(request)
    }

    static func fireDate(for trigger: UNNotificationTrigger?) -> Date? {
        guard let trigger else { return nil }
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return intervalTrigger.nextTriggerDate()
        }
        return nil
    }

    static func trigger(for fireDate: Date, now: Date) -> UNNotificationTrigger {
        let interval = fireDate.timeIntervalSince(now)
        if interval <= 86_400 {
            return UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    static let testNotificationID = "certwatch-test-notification"

    static func applicableThresholds(
        _ thresholds: [Int],
        daysRemaining: Int,
        validUntil: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [Int] {
        Array(Set(thresholds))
            .sorted(by: >)
            .filter { threshold in
                guard threshold <= daysRemaining else { return false }
                guard let fireDate = calendar.date(byAdding: .day, value: -threshold, to: validUntil) else {
                    return false
                }
                return fireDate > now
            }
    }

    func pruneNotifications(for endpointID: UUID, allowedThresholds: Set<Int>, now: Date) async {
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending.compactMap { request -> String? in
            guard request.identifier.hasPrefix("\(endpointID.uuidString)-") else { return nil }
            guard let parsed = Self.parseNotificationID(request.identifier) else {
                return request.identifier
            }
            if !allowedThresholds.contains(parsed.threshold) {
                return request.identifier
            }
            if let fireDate = Self.fireDate(for: request.trigger), fireDate <= now {
                return request.identifier
            }
            return nil
        }
        guard !staleIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)
    }

    static func notificationID(endpointID: UUID, threshold: Int) -> String {
        "\(endpointID.uuidString)-\(threshold)"
    }

    static func parseNotificationID(_ identifier: String) -> (endpointID: UUID, threshold: Int)? {
        guard let lastHyphen = identifier.lastIndex(of: "-") else { return nil }
        let thresholdPart = identifier[identifier.index(after: lastHyphen)...]
        guard let threshold = Int(thresholdPart) else { return nil }
        let uuidPart = String(identifier[..<lastHyphen])
        guard let endpointID = UUID(uuidString: uuidPart) else { return nil }
        return (endpointID, threshold)
    }

    static func notificationBody(for endpoint: MonitoredEndpoint, validUntil: Date, threshold: Int) -> String {
        notificationBody(hostPortLabel: endpoint.hostPortLabel, validUntil: validUntil, threshold: threshold)
    }

    static func notificationBody(hostPortLabel: String, validUntil: Date, threshold: Int) -> String {
        let dateText = DateFormatting.weekdayDate(validUntil)
        return "\(hostPortLabel) expires in \(threshold) day\(threshold == 1 ? "" : "s") (\(dateText))"
    }
}

enum NotificationSchedulerError: Error, LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notifications are not allowed. Enable them in iOS Settings → CertWatch."
        }
    }
}
