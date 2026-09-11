import SwiftUI
import UserNotifications

struct AddEndpointView: View {
    let store: EndpointStore?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKitManager: StoreKitManager

    @State private var input = ""
    @State private var displayName = ""
    @State private var tag = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("api.example.com or https://host:8443", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(CertWatchTheme.monospaced(15))

                    TextField("Display name (optional)", text: $displayName)
                }

                if AppSettings.isProUnlocked {
                    Section("Organisation") {
                        TextField("Tag (Production, Staging…)", text: $tag)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(CertWatchTheme.critical)
                            .font(.footnote)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CertWatchTheme.canvas)
            .navigationTitle("Add Domain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
        }
    }

    private func save() async {
        guard let store else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        switch HostnameParser.parse(input, defaultPort: AppSettings.defaultCheckPort) {
        case .failure(let error):
            errorMessage = error.localizedDescription
            return
        case .success(let parsed):
            do {
                _ = try await store.addEndpoint(
                    hostname: parsed.hostname,
                    port: parsed.port,
                    displayName: displayName,
                    tag: tag,
                    notes: notes
                )
                await requestNotificationPermissionIfNeeded()
                dismiss()
            } catch EndpointStoreError.limitReached {
                showingPaywall = true
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func requestNotificationPermissionIfNeeded() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }
}
