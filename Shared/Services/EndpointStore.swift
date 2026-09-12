import Foundation
import SwiftData
import WidgetKit

@MainActor
final class EndpointStore: ObservableObject {
    private let modelContext: ModelContext
    private let certificateService: any CertificateFetching
    private let notificationScheduler: NotificationScheduler

    @Published private(set) var isRefreshing = false

    init(
        modelContext: ModelContext,
        certificateService: (any CertificateFetching)? = nil,
        notificationScheduler: NotificationScheduler = NotificationScheduler()
    ) {
        self.modelContext = modelContext
        self.certificateService = certificateService ?? CertificateService()
        self.notificationScheduler = notificationScheduler
    }

    func fetchAll() throws -> [MonitoredEndpoint] {
        let descriptor = FetchDescriptor<MonitoredEndpoint>()
        return try modelContext.fetch(descriptor)
    }

    func sortedEndpoints() throws -> [MonitoredEndpoint] {
        MonitoredEndpoint.sortByExpiry(try fetchAll())
    }

    func canAddEndpoint() throws -> Bool {
        try fetchAll().count < AppSettings.endpointLimit
    }

    @discardableResult
    func addEndpoint(
        hostname: String,
        port: Int,
        displayName: String? = nil,
        tag: String? = nil,
        notes: String? = nil
    ) async throws -> MonitoredEndpoint {
        guard try canAddEndpoint() else {
            throw EndpointStoreError.limitReached
        }

        if try fetchAll().contains(where: { $0.hostname == hostname && $0.port == port }) {
            throw EndpointStoreError.duplicate
        }

        guard HostnameParser.isValidHostname(hostname), HostnameParser.isValidPort(port) else {
            throw EndpointStoreError.invalidEndpoint
        }

        let certificate = try await certificateService.fetchCertificateChain(host: hostname, port: port)

        let endpoint = MonitoredEndpoint(
            hostname: hostname,
            port: port,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tag: AppSettings.isProUnlocked ? tag?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            notes: AppSettings.isProUnlocked ? notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
        )

        modelContext.insert(endpoint)
        endpoint.apply(certificate: certificate)
        await scheduleNotifications(for: endpoint)
        try modelContext.save()
        reloadWidgets()
        return endpoint
    }

    func refresh(_ endpoint: MonitoredEndpoint) async throws {
        do {
            let certificate = try await certificateService.fetchCertificateChain(
                host: endpoint.hostname,
                port: endpoint.port
            )
            endpoint.apply(certificate: certificate)
        } catch {
            endpoint.apply(error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            throw error
        }

        await scheduleNotifications(for: endpoint)
    }

    private func scheduleNotifications(for endpoint: MonitoredEndpoint) async {
        do {
            try await notificationScheduler.scheduleNotifications(for: NotificationEndpoint(endpoint))
        } catch {
            // Certificate data is still valid even if local notifications could not be scheduled.
        }
    }

    func syncNotificationsWithEndpoints() async {
        do {
            let endpoints = try fetchAll()
            let validIDs = Set(endpoints.map(\.id))
            await notificationScheduler.removeOrphanedNotifications(validEndpointIDs: validIDs)
        } catch {
            await notificationScheduler.removeOrphanedNotifications(validEndpointIDs: [])
        }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let endpoints = try fetchAll()
            for endpoint in endpoints {
                try? await refresh(endpoint)
            }
            try modelContext.save()
            reloadWidgets()
        } catch {
            // Individual refresh errors are stored on endpoints.
        }
    }

    func delete(_ endpoint: MonitoredEndpoint) async throws {
        await notificationScheduler.removeNotifications(for: endpoint.id)
        modelContext.delete(endpoint)
        try modelContext.save()
        reloadWidgets()
    }

    func updateNotes(_ endpoint: MonitoredEndpoint, notes: String?) throws {
        guard AppSettings.isProUnlocked else { return }
        endpoint.notes = notes?.nilIfEmpty
        try modelContext.save()
    }

    func updateTag(_ endpoint: MonitoredEndpoint, tag: String?) throws {
        guard AppSettings.isProUnlocked else { return }
        endpoint.tag = tag.flatMap { EndpointTags.normalize($0) }
        try modelContext.save()
    }

    func deleteTag(_ tag: String) throws {
        guard AppSettings.isProUnlocked else { return }
        guard let normalized = EndpointTags.normalize(tag) else { return }

        for endpoint in try fetchAll() {
            if EndpointTags.normalize(endpoint.tag ?? "") == normalized {
                endpoint.tag = nil
            }
        }

        EndpointTags.removeFromCatalog(normalized)
        try modelContext.save()
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum EndpointStoreError: Error, LocalizedError {
    case limitReached
    case duplicate
    case invalidEndpoint

    var errorDescription: String? {
        switch self {
        case .limitReached:
            return "Free tier supports up to \(AppSettings.freeEndpointLimit) endpoints. Upgrade to Pro for unlimited monitoring."
        case .duplicate:
            return "This hostname and port is already being monitored."
        case .invalidEndpoint:
            return "Invalid hostname or port."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
