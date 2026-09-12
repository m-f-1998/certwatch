import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var storeKitManager: StoreKitManager

    @State private var thresholds = AppSettings.notificationThresholds
    @State private var defaultPort = AppSettings.defaultCheckPort
    @State private var backgroundRefresh = AppSettings.backgroundRefreshEnabled
    @State private var showingPaywall = false
    @State private var exportDocument: ExportDocumentShare?
    @State private var importError: String?
    @State private var importResult: ExportImportService.ImportResult?
    @State private var notificationStatus = "Checking…"
    @State private var pendingNotificationCount = 0

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

                Section("Notifications") {
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
                }

                Section("Checks") {
                    Stepper(value: $defaultPort, in: 1...65535) {
                        Text("Default port: \(defaultPort)")
                            .font(CertWatchTheme.monospaced(14))
                    }
                    if AppSettings.isProUnlocked {
                        Toggle("Daily background refresh", isOn: $backgroundRefresh)
                    }
                }

                if AppSettings.isProUnlocked {
                    Section("Data") {
                        Button("Export Endpoints") {
                            exportEndpoints()
                        }
                        .disabled(exportDocument != nil)

                        ImportEndpointButton { result in
                            switch result {
                            case .success(let summary):
                                importResult = summary
                            case .failure(let error):
                                importError = error.localizedDescription
                            }
                        }
                    }
                }

                Section("Support") {
                    Link("Support", destination: AppMetadata.supportURL)
                    Link("Privacy Policy", destination: AppMetadata.privacyPolicyURL)
                    Link("Send Feedback", destination: AppMetadata.feedbackURL)
                    LabeledContent("Version", value: AppMetadata.versionLabel)
                }

                if let importResult {
                    Section {
                        Text("Imported \(importResult.imported), skipped \(importResult.skipped) duplicates.")
                    }
                }

                if let importError {
                    Section {
                        Text(importError)
                            .foregroundStyle(CertWatchTheme.critical)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CertWatchTheme.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
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
                Task { await refreshNotificationStatus() }
            }
        }
    }

    private func refreshNotificationStatus() async {
        let scheduler = NotificationScheduler()
        let store = EndpointStore(modelContext: modelContext, notificationScheduler: scheduler)
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
    }

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

    private func saveSettings() {
        AppSettings.defaultCheckPort = defaultPort
        if AppSettings.isProUnlocked {
            AppSettings.notificationThresholds = thresholds
            AppSettings.backgroundRefreshEnabled = backgroundRefresh
            BackgroundRefreshService.scheduleNextRefresh()
        }
    }

    private func exportEndpoints() {
        do {
            let endpoints = try modelContext.fetch(FetchDescriptor<MonitoredEndpoint>())
            let data = try ExportImportService.export(endpoints: endpoints)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("certwatch-export.json")
            try data.write(to: url)
            exportDocument = ExportDocumentShare(url: url)
        } catch {
            importError = error.localizedDescription
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
    let onComplete: (Result<ExportImportService.ImportResult, Error>) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var showingImporter = false

    var body: some View {
        Button("Import Endpoints") {
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
