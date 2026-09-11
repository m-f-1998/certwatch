import Combine
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Query private var endpoints: [MonitoredEndpoint]

    @StateObject private var storeHolder = StoreHolder()
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if filteredEndpoints.isEmpty {
                        emptyState
                    } else {
                        ForEach(filteredEndpoints, id: \.id) { endpoint in
                            NavigationLink {
                                EndpointDetailView(endpoint: endpoint)
                            } label: {
                                EndpointCardView(endpoint: endpoint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(CertWatchTheme.canvas)
            .navigationTitle("CertWatch")
            .searchable(text: $searchText, prompt: "Search hostnames")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if storeHolder.isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await storeHolder.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh all certificates")
                    }

                    Button {
                        if storeHolder.canAddEndpoint {
                            showingAddSheet = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add endpoint")
                }
            }
            .refreshable {
                await storeHolder.refreshAll()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEndpointView(store: storeHolder.store)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
            .onAppear {
                storeHolder.configureIfNeeded(modelContext: modelContext)
            }
        }
    }

    private var filteredEndpoints: [MonitoredEndpoint] {
        var items = MonitoredEndpoint.sortByExpiry(endpoints)

        if !searchText.isEmpty {
            items = items.filter {
                $0.hostname.localizedCaseInsensitiveContains(searchText)
                    || ($0.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return items
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 36))
                    .foregroundStyle(CertWatchTheme.healthy)
                Text("Add your first domain")
                    .font(.title3.bold())
                Text("Monitor certificate expiry and get alerts before downtime.")
                    .font(.subheadline)
                    .foregroundStyle(CertWatchTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Button("Add Domain") {
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(CertWatchTheme.healthy)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

@MainActor
private final class StoreHolder: ObservableObject {
    @Published private(set) var store: EndpointStore?
    @Published private(set) var isRefreshing = false
    @Published private(set) var canAddEndpoint = true

    private var cancellable: AnyCancellable?

    func configureIfNeeded(modelContext: ModelContext) {
        guard store == nil else { return }

        let endpointStore = EndpointStore(modelContext: modelContext)
        store = endpointStore
        refreshDerivedState(from: endpointStore)

        cancellable = endpointStore.objectWillChange.sink { [weak self] _ in
            guard let self, let store = self.store else { return }
            self.refreshDerivedState(from: store)
        }
    }

    func refreshAll() async {
        await store?.refreshAll()
    }

    private func refreshDerivedState(from store: EndpointStore) {
        isRefreshing = store.isRefreshing
        canAddEndpoint = (try? store.canAddEndpoint()) ?? false
    }
}

struct EndpointCardView: View {
    let endpoint: MonitoredEndpoint

    var body: some View {
        let status = ExpiryBadgeStyle.status(for: endpoint)
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(status.color)
                                .frame(width: 8, height: 8)
                            Text(endpoint.title)
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                            if endpoint.port != 443 {
                                Text(":\(endpoint.port)")
                                    .font(CertWatchTheme.monospaced(12))
                                    .foregroundStyle(CertWatchTheme.secondaryText)
                            }
                        }

                        Text("Issuer: \(endpoint.issuerCN ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(CertWatchTheme.secondaryText)

                        if let validUntil = endpoint.validUntil {
                            Text("Expires \(DateFormatting.mediumDate(validUntil))")
                                .font(.caption)
                                .foregroundStyle(CertWatchTheme.tertiaryText)
                        } else if let error = endpoint.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(CertWatchTheme.muted)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 8)
                    ExpiryPill(text: ExpiryBadgeStyle.pillText(for: endpoint), status: status)
                }

                ValidityProgressRail(
                    progress: ExpiryBadgeStyle.validityProgress(
                        validFrom: endpoint.validFrom,
                        validUntil: endpoint.validUntil
                    ),
                    tint: status.color
                )
            }
        }
    }
}
