import SwiftData
import SwiftUI

struct AppStoreScreenshotRootView: View {
    let scene: AppStoreScreenshotScene

    @Query(sort: \MonitoredEndpoint.validUntil) private var endpoints: [MonitoredEndpoint]
    @StateObject private var storeKitManager = StoreKitManager()

    var body: some View {
        Group {
            switch scene {
            case .dashboard:
                NavigationStack {
                    DashboardView()
                }
            case .detail:
                NavigationStack {
                    if let endpoint = endpoints.first(where: { $0.hostname == "api.matthewfrankland.com" }) ?? endpoints.first {
                        EndpointDetailView(endpoint: endpoint)
                    } else {
                        ContentUnavailableView("No sample endpoint", systemImage: "exclamationmark.triangle")
                    }
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .environmentObject(storeKitManager)
        .preferredColorScheme(.dark)
        .background(CertWatchTheme.canvas.ignoresSafeArea())
    }
}
