import Foundation
import SwiftData
import WidgetKit

@MainActor
final class EndpointStore: ObservableObject {
    private let modelContext: ModelContext
    private let certificateService: CertificateService
    private let notificationScheduler: NotificationScheduler

    @Published private(set) var isRefreshing = false

    init(
        modelContext: ModelContext,
        certificateService: CertificateService = CertificateService(),
        notificationScheduler: NotificationScheduler = NotificationScheduler()
    ) {
        self.modelContext = modelContext
        self.certificateService = certificateService
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

        let endpoint = MonitoredEndpoint(
            hostname: hostname,
            port: port,
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tag: AppSettings.isProUnlocked ? tag?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            notes: AppSettings.isProUnlocked ? notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
        )

        modelContext.insert(endpoint)
        try await refresh(endpoint)
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
            try await notificationScheduler.scheduleNotifications(for: NotificationEndpoint(endpoint))
        } catch {
            endpoint.apply(error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            throw error
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
        endpoint.tag = tag?.nilIfEmpty
        try modelContext.save()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum EndpointStoreError: Error, LocalizedError {
    case limitReached
    case duplicate

    var errorDescription: String? {
        switch self {
        case .limitReached:
            return "Free tier supports up to \(AppSettings.freeEndpointLimit) endpoints. Upgrade to Pro for unlimited monitoring."
        case .duplicate:
            return "This hostname and port is already being monitored."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
