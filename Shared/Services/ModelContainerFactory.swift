import SwiftData

enum ModelContainerFactory {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([MonitoredEndpoint.self])
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                groupContainer: .identifier(AppSettings.appGroupID)
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
