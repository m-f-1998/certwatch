import SwiftData
import WidgetKit

struct EndpointSnapshot: TimelineEntry {
    let date: Date
    let endpoints: [EndpointWidgetModel]
}

struct EndpointWidgetModel: Identifiable {
    let id: UUID
    let title: String
    let hostPortLabel: String
    let daysRemaining: Int
    let status: ExpiryStatus
}

struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> EndpointSnapshot {
        EndpointSnapshot(date: .now, endpoints: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (EndpointSnapshot) -> Void) {
        completion(loadSnapshot() ?? EndpointSnapshot(date: .now, endpoints: Self.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EndpointSnapshot>) -> Void) {
        let snapshot = loadSnapshot() ?? EndpointSnapshot(date: .now, endpoints: [])
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 3, to: .now) ?? .now.addingTimeInterval(10_800)
        completion(Timeline(entries: [snapshot], policy: .after(nextUpdate)))
    }

    private func loadSnapshot() -> EndpointSnapshot? {
        guard AppSettings.isProUnlocked else {
            return EndpointSnapshot(date: .now, endpoints: [])
        }

        do {
            let container = try ModelContainerFactory.makeContainer()
            let context = ModelContext(container)
            let endpoints = try context.fetch(FetchDescriptor<MonitoredEndpoint>())
            let sorted = MonitoredEndpoint.sortByExpiry(endpoints)
            let models = sorted.prefix(3).map { endpoint in
                EndpointWidgetModel(
                    id: endpoint.id,
                    title: endpoint.title,
                    hostPortLabel: endpoint.hostPortLabel,
                    daysRemaining: endpoint.validUntil.map { ExpiryBadgeStyle.daysRemaining(until: $0) } ?? -1,
                    status: ExpiryBadgeStyle.status(for: endpoint)
                )
            }
            return EndpointSnapshot(date: .now, endpoints: Array(models))
        } catch {
            return nil
        }
    }

    private static let sample: [EndpointWidgetModel] = [
        EndpointWidgetModel(
            id: UUID(),
            title: "api.example.com",
            hostPortLabel: "api.example.com",
            daysRemaining: 38,
            status: .healthy
        )
    ]
}
