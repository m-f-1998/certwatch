import Combine
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKitManager: StoreKitManager
    @Query private var endpoints: [MonitoredEndpoint]

    @StateObject private var storeHolder = StoreHolder()
    @State private var searchText = ""
    @State private var selectedTagFilter: String?
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if AppSettings.isProUnlocked, !tagFilterOptions.isEmpty {
                        TagFilterBar(selectedTag: $selectedTagFilter, tags: tagFilterOptions)
                    }

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
                Task { await storeHolder.syncNotifications() }
            }
        }
    }

    private var filteredEndpoints: [MonitoredEndpoint] {
        var items = MonitoredEndpoint.sortByExpiry(endpoints)

        if AppSettings.isProUnlocked, let selectedTagFilter {
            items = items.filter { EndpointTags.normalize($0.tag ?? "") == selectedTagFilter }
        }

        if !searchText.isEmpty {
            items = items.filter { endpoint in
                endpoint.hostname.localizedCaseInsensitiveContains(searchText)
                    || (endpoint.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || (AppSettings.isProUnlocked && (endpoint.tag?.localizedCaseInsensitiveContains(searchText) ?? false))
                    || (AppSettings.isProUnlocked && (endpoint.subjectCN?.localizedCaseInsensitiveContains(searchText) ?? false))
                    || (AppSettings.isProUnlocked && (endpoint.issuerCN?.localizedCaseInsensitiveContains(searchText) ?? false))
            }
        }

        return items
    }

    private var tagFilterOptions: [(name: String, count: Int)] {
        EndpointTags.filterOptions(from: endpoints)
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: emptyStateSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(CertWatchTheme.healthy)
                Text(emptyStateTitle)
                    .font(.title3.bold())
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(CertWatchTheme.secondaryText)
                    .multilineTextAlignment(.center)
                if endpoints.isEmpty {
                    Button("Add Domain") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CertWatchTheme.healthy)
                } else if selectedTagFilter != nil {
                    Button("Show All Tags") {
                        selectedTagFilter = nil
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private var emptyStateSymbol: String {
        if selectedTagFilter != nil, !endpoints.isEmpty {
            return "tag.slash"
        }
        return "network.badge.shield.half.filled"
    }

    private var emptyStateTitle: String {
        if endpoints.isEmpty {
            return "Add your first domain"
        }
        if selectedTagFilter != nil {
            return "No domains with this tag"
        }
        if !searchText.isEmpty {
            return "No matching domains"
        }
        return "No domains"
    }

    private var emptyStateMessage: String {
        if endpoints.isEmpty {
            return "Monitor certificate expiry and get alerts before downtime."
        }
        if let selectedTagFilter {
            return "Nothing is tagged “\(selectedTagFilter)”. Pick another tag or clear the filter."
        }
        if !searchText.isEmpty {
            return "Try a different search term."
        }
        return "Add a domain to start monitoring."
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
        guard let store, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await store.refreshAll()
    }

    func syncNotifications() async {
        _ = await NotificationRescheduleService.rescheduleIfAuthorizationGranted()
        await store?.syncNotificationsWithEndpoints()
    }

    private func refreshDerivedState(from store: EndpointStore) {
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
                            if AppSettings.isProUnlocked,
                               let tag = EndpointTags.normalize(endpoint.tag ?? "") {
                                TagChipLabel(title: tag)
                            }
                        }

                        if endpoint.showsHostnameSubtitle {
                            Text(endpoint.hostPortLabel)
                                .font(CertWatchTheme.monospaced(12))
                                .foregroundStyle(CertWatchTheme.tertiaryText)
                        }

                        if endpoint.showsSubjectSubtitle, let subjectCN = endpoint.subjectCN {
                            Text("Subject: \(subjectCN)")
                                .font(.caption)
                                .foregroundStyle(CertWatchTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Text("Issuer: \(endpoint.issuerCN ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(CertWatchTheme.secondaryText)
                            .lineLimit(1)

                        if let validUntil = endpoint.validUntil {
                            Text("Expires \(DateFormatting.mediumDate(validUntil))")
                                .font(.caption)
                                .foregroundStyle(status.color.opacity(0.85))
                        } else if let error = endpoint.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(CertWatchTheme.muted)
                                .lineLimit(2)
                        }

                        if AppSettings.isProUnlocked {
                            proListingDetails
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

    @ViewBuilder
    private var proListingDetails: some View {
        if endpoint.isReachable {
            VStack(alignment: .leading, spacing: 6) {
                Text(proMetadataLine)
                    .font(.caption2)
                    .foregroundStyle(CertWatchTheme.tertiaryText)
                    .lineLimit(2)

                if let lastCheckedAt = endpoint.lastCheckedAt {
                    Text("Checked \(DateFormatting.relativeTimeAgo(since: lastCheckedAt))")
                        .font(.caption2)
                        .foregroundStyle(CertWatchTheme.tertiaryText)
                }
            }
            .padding(.top, 2)
        }
    }

    private var proMetadataLine: String {
        var parts: [String] = []

        if let publicKeyDescription = endpoint.publicKeyDescription, publicKeyDescription != "Unknown" {
            parts.append(publicKeyDescription)
        }

        let chainCount = endpoint.chainCertificateCount
        if chainCount > 0 {
            parts.append("\(chainCount) cert\(chainCount == 1 ? "" : "s")")
        }

        let sanCount = endpoint.subjectAlternativeNames.count
        if sanCount > 0 {
            parts.append("\(sanCount) SAN\(sanCount == 1 ? "" : "s")")
        }

        if parts.isEmpty {
            return "Certificate details available"
        }
        return parts.joined(separator: " · ")
    }
}
