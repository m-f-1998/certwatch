import Foundation
import SwiftData

struct ExportDocument: Codable, Equatable {
    let version: Int
    let endpoints: [ExportEndpoint]

    struct ExportEndpoint: Codable, Equatable {
        let hostname: String
        let port: Int
        let displayName: String?
        let tag: String?
        let notes: String?
    }
}

enum ExportImportService {
    static func export(endpoints: [MonitoredEndpoint]) throws -> Data {
        let payload = ExportDocument(
            version: 1,
            endpoints: endpoints.map {
                ExportDocument.ExportEndpoint(
                    hostname: $0.hostname,
                    port: $0.port,
                    displayName: $0.displayName,
                    tag: $0.tag,
                    notes: $0.notes
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func decode(_ data: Data) throws -> ExportDocument {
        try JSONDecoder().decode(ExportDocument.self, from: data)
    }

    @MainActor
    static func importEndpoints(
        from data: Data,
        into store: EndpointStore
    ) async throws -> ImportResult {
        let document = try decode(data)
        var imported = 0
        var skipped = 0

        guard !document.endpoints.isEmpty else {
            return ImportResult(imported: 0, skipped: 0)
        }

        await NotificationScheduler().requestAuthorizationIfNeeded()

        for item in document.endpoints {
            do {
                _ = try await store.addEndpoint(
                    hostname: item.hostname,
                    port: item.port,
                    displayName: item.displayName,
                    tag: item.tag,
                    notes: item.notes
                )
                imported += 1
            } catch EndpointStoreError.duplicate {
                skipped += 1
            } catch EndpointStoreError.limitReached {
                throw EndpointStoreError.limitReached
            }
        }

        return ImportResult(imported: imported, skipped: skipped)
    }

    struct ImportResult: Equatable {
        let imported: Int
        let skipped: Int
    }
}
