import SwiftData
import SwiftUI

@main
struct CertWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
                    await NotificationRescheduleService.syncWithStoredAuthorization()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await NotificationRescheduleService.syncWithStoredAuthorization() }
                }
        }
        .modelContainer(modelContainer)
    }
}
