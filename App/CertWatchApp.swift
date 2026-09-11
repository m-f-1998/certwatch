import SwiftUI
import SwiftData

@main
struct CertWatchApp: App {
    @StateObject private var storeKitManager = StoreKitManager()

    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeContainer()
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(storeKitManager)
                .preferredColorScheme(.dark)
                .task {
                    await storeKitManager.loadProducts()
                    await storeKitManager.refreshEntitlements()
                    BackgroundRefreshService.scheduleNextRefresh()
                }
        }
        .modelContainer(modelContainer)
    }
}
