import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeKitManager: StoreKitManager

    @State private var thresholds = AppSettings.notificationThresholds
    @State private var defaultPort = AppSettings.defaultCheckPort
    @State private var backgroundRefresh = AppSettings.backgroundRefreshEnabled
    @State private var showingPaywall = false
    @State private var exportDocument: ExportDocumentShare?
    @State private var dataError: String?
    @State private var notificationStatus = "Checking…"
    @State private var pendingNotificationCount = 0
    #if DEBUG
    @State private var upcomingAlerts: [ScheduledAlert] = []
    @State private var notificationFooter: String?
    @State private var isSendingTestNotification = false
    @State private var isReschedulingNotifications = false
    @State private var isUpcomingAlertsExpanded = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                if !AppSettings.isProUnlocked {
                    Section {
                        Button("Unlock CertWatch Pro") {
                            showingPaywall = true
                        }
                    }
                }

                Section {
                    if AppSettings.isProUnlocked {
                        Stepper(value: thresholdBinding(for: 0), in: 1...365) {
                            Text("First alert: \(thresholds[safe: 0] ?? 30) days before")
                        }
                        Stepper(value: thresholdBinding(for: 1), in: 1...365) {
                            Text("Second alert: \(thresholds[safe: 1] ?? 14) days before")
                        }
                        Stepper(value: thresholdBinding(for: 2), in: 1...365) {
                            Text("Third alert: \(thresholds[safe: 2] ?? 7) days before")
                        }
                        Stepper(value: thresholdBinding(for: 3), in: 1...365) {
                            Text("Final alert: \(thresholds[safe: 3] ?? 1) day before")
                        }
                    } else {
                        Text("Free tier includes one alert 30 days before expiry.")
                            .foregroundStyle(CertWatchTheme.secondaryText)
                    }

                    LabeledContent("Permission", value: notificationStatus)
                    LabeledContent("Scheduled alerts", value: "\(pendingNotificationCount)")

                    if notificationStatus == "Denied" {
                        Button("Open iOS Notification Settings") {
                            openNotificationSettings()
                        }
                    }

                    #if DEBUG
                    notificationDebugSection
                    #endif
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationStatus == "Denied" {
                        Text("Enable notifications in iOS Settings, then return to CertWatch — your alerts will reschedule automatically.")
                    } else if notificationStatus == "Not requested" {
                        Text("You'll be asked to allow notifications when you add or import a domain.")
                    }
                    #if DEBUG
                    if let notificationFooter {
                        Text(notificationFooter)
                    }
                    #endif
                }

                Section("Checks") {
                    Stepper(value: $defaultPort, in: 1...65535) {
                        Text("Default port: \(defaultPort)")
                            .font(CertWatchTheme.monospaced(14))
                    }
                    if AppSettings.isProUnlocked {
                        Toggle("Daily background refresh", isOn: $backgroundRefresh)
                        Text("About once a day, CertWatch re-checks your saved domains in the background and updates expiry dates, alerts, and widgets. iOS decides the exact timing.")
                            .font(.caption)
                            .foregroundStyle(CertWatchTheme.secondaryText)
                    }
                }

                if AppSettings.isProUnlocked {
                    Section {
                        Button("Export Endpoints") {
                            exportEndpoints()
                        }
                        .disabled(exportDocument != nil)

                        ImportEndpointButton(
                            onStart: { dataError = nil },
                            onComplete: { result in
                                switch result {
                                case .success:
                                    Task { await saveSettingsAndDismiss() }
                                case .failure(let error):
                                    dataError = error.localizedDescription
                                }
                            }
                        )
                    } header: {
                        Text("Data")
                    } footer: {
                        if let dataError {
                            Text(dataError)
                                .foregroundStyle(CertWatchTheme.critical)
                        }
                    }
                }

                Section("Support") {
                    Link("Support", destination: AppMetadata.supportURL)
                    Link("Privacy Policy", destination: AppMetadata.privacyPolicyURL)
                    Link("Send Feedback", destination: AppMetadata.feedbackURL)
                    LabeledContent("Version", value: AppMetadata.versionLabel)
                }

            }
            .scrollContentBackground(.hidden)
            .background(CertWatchTheme.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Task {
                            await saveSettingsAndDismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
            .sheet(item: $exportDocument) { document in
                ShareSheet(items: [document.url])
            }
            .task {
                await refreshNotificationStatus()
            }
            .onAppear {
                reloadThresholdsFromSettings()
                Task { await refreshNotificationStatus() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refreshNotificationStatus() }
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func reloadThresholdsFromSettings() {
        if AppSettings.isProUnlocked {
            thresholds = AppSettings.normalizedProThresholds(
                AppSettings.notificationThresholds
            )
        } else {
            thresholds = AppSettings.notificationThresholds
        }
    }

    private func refreshNotificationStatus() async {
        let scheduler = NotificationScheduler()
        let store = EndpointStore(modelContext: modelContext, notificationScheduler: scheduler)
        let didReschedule = await NotificationRescheduleService.rescheduleIfAuthorizationGranted()
        await store.syncNotificationsWithEndpoints()

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = switch settings.authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .denied: "Denied"
        case .notDetermined: "Not requested"
        case .ephemeral: "Ephemeral"
        @unknown default: "Unknown"
        }

        pendingNotificationCount = await scheduler.certWatchPendingCount()
        #if DEBUG
        upcomingAlerts = await scheduler.pendingAlerts()
        if didReschedule {
            notificationFooter = "Alerts rescheduled after notification permission changed."
        }
        #endif
    }

    #if DEBUG
    @ViewBuilder
    private var notificationDebugSection: some View {
        if let nextAlert = upcomingAlerts.first, let fireDate = nextAlert.fireDate {
            LabeledContent("Next alert") {
                Text(DateFormatting.mediumDateTime(fireDate))
                    .foregroundStyle(CertWatchTheme.secondaryText)
            }
            Text("\(nextAlert.hostPortLabel) · \(nextAlert.threshold) days before")
                .font(.caption)
                .foregroundStyle(CertWatchTheme.tertiaryText)
        } else if notificationStatus == "Allowed" {
            Text("No upcoming alerts. Tap Reschedule below after changing thresholds or adding domains.")
                .font(.caption)
                .foregroundStyle(CertWatchTheme.secondaryText)
        }

        Button {
            Task { await sendTestNotification() }
        } label: {
            if isSendingTestNotification {
                HStack {
                    ProgressView()
                    Text("Scheduling test…")
                }
            } else {
                Text("Send test alert in 10 seconds")
            }
        }
        .disabled(isSendingTestNotification || notificationStatus == "Denied")

        Button {
            Task { await rescheduleNotificationsNow() }
        } label: {
            if isReschedulingNotifications {
                HStack {
                    ProgressView()
                    Text("Rescheduling…")
                }
            } else {
                Text("Reschedule alerts now")
            }
        }
        .disabled(isReschedulingNotifications || notificationStatus == "Denied")

        if !upcomingAlerts.isEmpty {
            DisclosureGroup(
                "Upcoming alerts (\(upcomingAlerts.count))",
                isExpanded: $isUpcomingAlertsExpanded
            ) {
                ForEach(upcomingAlerts.prefix(8)) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.hostPortLabel)
                            .font(.subheadline.weight(.semibold))
                        if let fireDate = alert.fireDate {
                            Text(DateFormatting.mediumDateTime(fireDate))
                                .font(.caption)
                                .foregroundStyle(CertWatchTheme.secondaryText)
                        }
                        Text("Alert threshold: \(alert.threshold) days before expiry")
                            .font(.caption2)
                            .foregroundStyle(CertWatchTheme.tertiaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        Text("Debug only — not shown in App Store builds. Alerts are scheduled locally; background refresh re-checks certificates only.")
            .font(.caption)
            .foregroundStyle(CertWatchTheme.tertiaryText)
    }

    private func sendTestNotification() async {
        isSendingTestNotification = true
        notificationFooter = nil
        defer { isSendingTestNotification = false }

        let scheduler = NotificationScheduler()
        do {
            try await scheduler.scheduleTestNotification(after: 10)
            notificationFooter = "Test alert scheduled. Background the app or lock your phone within 10 seconds."
        } catch {
            notificationFooter = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func rescheduleNotificationsNow() async {
        isReschedulingNotifications = true
        notificationFooter = nil
        defer { isReschedulingNotifications = false }

        if AppSettings.isProUnlocked {
            AppSettings.notificationThresholds = AppSettings.normalizedProThresholds(thresholds)
        }

        let scheduler = NotificationScheduler()
        let store = EndpointStore(modelContext: modelContext, notificationScheduler: scheduler)
        do {
            try await store.rescheduleAllNotifications()
            await refreshNotificationStatus()
            isUpcomingAlertsExpanded = true
            let thresholdSummary = AppSettings.uniqueThresholdsForScheduling(
                AppSettings.notificationThresholds
            )
                .map { "\($0)d" }
                .joined(separator: ", ")
            notificationFooter = "Scheduled \(pendingNotificationCount) alert\(pendingNotificationCount == 1 ? "" : "s") (\(thresholdSummary))."
        } catch {
            notificationFooter = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
    #endif

    private func thresholdBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { thresholds[safe: index] ?? AppSettings.defaultThresholds[safe: index] ?? 30 },
            set: { newValue in
                while thresholds.count <= index {
                    thresholds.append(AppSettings.defaultThresholds[safe: thresholds.count] ?? 30)
                }
                thresholds[index] = newValue
            }
        )
    }

    private func saveSettingsAndDismiss() async {
        AppSettings.defaultCheckPort = defaultPort
        if AppSettings.isProUnlocked {
            AppSettings.notificationThresholds = AppSettings.normalizedProThresholds(thresholds)
            AppSettings.backgroundRefreshEnabled = backgroundRefresh
            BackgroundRefreshService.scheduleNextRefresh()
        }

        let scheduler = NotificationScheduler()
        let store = EndpointStore(modelContext: modelContext, notificationScheduler: scheduler)
        try? await store.rescheduleAllNotifications()
        dismiss()
    }

    private func exportEndpoints() {
        dataError = nil
        do {
            let endpoints = try modelContext.fetch(FetchDescriptor<MonitoredEndpoint>())
            let data = try ExportImportService.export(endpoints: endpoints)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("certwatch-export.json")
            try data.write(to: url)
            exportDocument = ExportDocumentShare(url: url)
        } catch {
            dataError = error.localizedDescription
        }
    }
}

private struct ExportDocumentShare: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ImportEndpointButton: View {
    let onStart: () -> Void
    let onComplete: (Result<ExportImportService.ImportResult, Error>) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingImporter = false

    var body: some View {
        Button("Import Endpoints") {
            onStart()
            showingImporter = true
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            Task { @MainActor in
                do {
                    let url = try result.get()
                    let needsAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if needsAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let data = try Data(contentsOf: url)
                    let store = EndpointStore(modelContext: modelContext)
                    let summary = try await ExportImportService.importEndpoints(from: data, into: store)
                    onComplete(.success(summary))
                } catch {
                    onComplete(.failure(error))
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
