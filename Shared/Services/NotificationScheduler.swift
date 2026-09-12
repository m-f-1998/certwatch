import Foundation
import UserNotifications

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
    func scheduleNotifications(for endpoint: NotificationEndpoint) async throws
    func removeNotifications(for endpointID: UUID) async
    func rescheduleAll(_ endpoints: [NotificationEndpoint]) async throws
    func removeOrphanedNotifications(validEndpointIDs: Set<UUID>) async
    func certWatchPendingCount() async -> Int
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

    func scheduleNotifications(for endpoint: NotificationEndpoint) async throws {
        await removeNotifications(for: endpoint.id)
        guard endpoint.isReachable, let validUntil = endpoint.validUntil else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let thresholds = thresholdsProvider()
        let now = nowProvider()

        for threshold in thresholds {
            guard let fireDate = Calendar.current.date(byAdding: .day, value: -threshold, to: validUntil),
                  fireDate > now else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Certificate expiring soon"
            content.body = Self.notificationBody(
                hostPortLabel: endpoint.hostPortLabel,
                validUntil: validUntil,
                threshold: threshold
            )
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = Self.notificationID(endpointID: endpoint.id, threshold: threshold)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try await center.add(request)
        }
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
