import SwiftUI

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
    @State private var tagSuggestions: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("api.example.com or https://host:8443", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(CertWatchTheme.monospaced(15))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .onChange(of: input) { _, _ in
                            errorMessage = nil
                        }

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(CertWatchTheme.critical)
                    } else if case .success(let parsed) = parsedInput {
                        Text(parsedPreview(for: parsed))
                            .font(.footnote)
                            .foregroundStyle(CertWatchTheme.secondaryText)
                    }

                    TextField("Display name (optional)", text: $displayName)
                }

                if AppSettings.isProUnlocked {
                    Section("Organisation") {
                        TagPickerField(
                            selection: $tag,
                            suggestions: tagSuggestions,
                            onDeleteTag: { tag in
                                deleteTagFromCatalog(tag)
                            }
                        )
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                } else if let store, let endpointCount = try? store.fetchAll().count {
                    Section {
                        Text("\(endpointCount) of \(AppSettings.freeEndpointLimit) free endpoints used")
                            .foregroundStyle(CertWatchTheme.secondaryText)
                            .font(.footnote)
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
                    .disabled(isSaving || !canSave)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
                    .environmentObject(storeKitManager)
            }
            .onAppear {
                reloadTagSuggestions()
            }
        }
    }

    private func reloadTagSuggestions() {
        guard let store else {
            tagSuggestions = EndpointTags.pickerOptions(from: [])
            return
        }
        let endpoints = (try? store.fetchAll()) ?? []
        tagSuggestions = EndpointTags.pickerOptions(from: endpoints)
    }

    private func deleteTagFromCatalog(_ tag: String) {
        try? store?.deleteTag(tag)
        if EndpointTags.normalize(self.tag) == EndpointTags.normalize(tag) {
            self.tag = ""
        }
        reloadTagSuggestions()
    }

    private var parsedInput: Result<ParsedHost, HostnameParser.ParseError> {
        HostnameParser.parse(input, defaultPort: AppSettings.defaultCheckPort)
    }

    private var canSave: Bool {
        if case .success = parsedInput { return true }
        return false
    }

    private var validationMessage: String? {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if case .failure(let error) = parsedInput {
            return error.localizedDescription
        }
        return nil
    }

    private var normalizedTag: String? {
        EndpointTags.normalize(tag)
    }

    private func parsedPreview(for parsed: ParsedHost) -> String {
        if parsed.port == 443 {
            return "Will monitor \(parsed.hostname) on port 443"
        }
        return "Will monitor \(parsed.hostname):\(parsed.port)"
    }

    private func save() async {
        guard let store else { return }

        guard case .success(let parsed) = parsedInput else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            if let normalizedTag {
                EndpointTags.remember(normalizedTag)
            }
            await NotificationScheduler().requestAuthorizationIfNeeded()
            _ = try await store.addEndpoint(
                hostname: parsed.hostname,
                port: parsed.port,
                displayName: displayName,
                tag: normalizedTag,
                notes: notes
            )
            dismiss()
        } catch EndpointStoreError.limitReached {
            showingPaywall = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

}
