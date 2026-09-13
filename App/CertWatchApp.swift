import SwiftData
import SwiftUI

@main
struct CertWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var storeKitManager = StoreKitManager()

    private let modelContainer: ModelContainer
    private let screenshotScene: AppStoreScreenshotScene?

    init() {
        screenshotScene = AppStoreScreenshotSupport.scene(from: ProcessInfo.processInfo.arguments)

        do {
            if screenshotScene != nil {
                AppStoreScreenshotSupport.configureForCapture()
                modelContainer = try AppStoreScreenshotSupport.makeSeededContainer()
            } else {
                modelContainer = try ModelContainerFactory.makeContainer()
            }
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }

        if screenshotScene == nil {
            BackgroundRefreshService.register()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let screenshotScene {
                    AppStoreScreenshotRootView(scene: screenshotScene)
                } else {
                    RootView()
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
            }
            .environmentObject(storeKitManager)
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
