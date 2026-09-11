import SwiftData
import SwiftUI
import UIKit

struct EndpointDetailView: View {
    @Bindable var endpoint: MonitoredEndpoint
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var store: EndpointStore?
    @State private var isRefreshing = false
    @State private var selectedChainIndex = 0
    @State private var notesDraft = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroSection
                securitySection
                sanSection
                chainSection
                pemSection
                metadataSection
                if AppSettings.isProUnlocked {
                    notesSection
                }
                actionsSection
            }
            .padding()
        }
        .background(CertWatchTheme.canvas)
        .navigationTitle(endpoint.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if store == nil {
                store = EndpointStore(modelContext: modelContext)
            }
            notesDraft = endpoint.notes ?? ""
        }
    }

    private var heroSection: some View {
        GlassCard {
            VStack(spacing: 16) {
                CountdownDial(
                    daysRemaining: endpoint.validUntil.map {
                        ExpiryBadgeStyle.daysRemaining(until: $0)
                    } ?? -1,
                    status: ExpiryBadgeStyle.status(for: endpoint)
                )

                Text(endpoint.hostPortLabel)
                    .font(CertWatchTheme.monospaced(16, weight: .semibold))

                if let validUntil = endpoint.validUntil {
                    Text(DateFormatting.relativeDaysAndHours(until: validUntil))
                        .foregroundStyle(CertWatchTheme.secondaryText)
                } else if let error = endpoint.lastError {
                    Text(error)
                        .foregroundStyle(CertWatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var securitySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Security Signals")
                HStack(spacing: 8) {
                    SecurityBadge(title: "Signature", value: endpoint.signatureAlgorithm ?? "Unknown")
                    SecurityBadge(title: "Key", value: endpoint.publicKeyDescription ?? "Unknown")
                }
                detailRow("Issuer", endpoint.issuerCN ?? "Unknown")
                detailRow("Subject", endpoint.subjectCN ?? "Unknown")
                detailRow("Serial", endpoint.serialNumber ?? "Unknown")
            }
        }
    }

    private var sanSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Subject Alternative Names")
                if endpoint.subjectAlternativeNames.isEmpty {
                    Text("No SAN entries recorded.")
                        .foregroundStyle(CertWatchTheme.secondaryText)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(endpoint.subjectAlternativeNames, id: \.self) { san in
                            Text(san)
                                .font(CertWatchTheme.monospaced(12))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08), in: Capsule())
                                .onTapGesture {
                                    UIPasteboard.general.string = san
                                }
                        }
                    }
                }
            }
        }
    }

    private var chainSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Certificate Chain")
                let chain = endpoint.chainCertificates
                if chain.isEmpty {
                    Text("Chain unavailable until next successful check.")
                        .foregroundStyle(CertWatchTheme.secondaryText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(chain.enumerated()), id: \.offset) { index, cert in
                                Button {
                                    selectedChainIndex = index
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(index == 0 ? "Leaf" : index == chain.count - 1 ? "Root" : "Intermediate")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(CertWatchTheme.tertiaryText)
                                        Text(cert.subjectCommonName ?? "Unknown")
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(width: 120, alignment: .leading)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedChainIndex == index ? CertWatchTheme.healthy.opacity(0.18) : Color.white.opacity(0.06))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if chain.indices.contains(selectedChainIndex) {
                        let cert = chain[selectedChainIndex]
                        detailRow("Valid From", DateFormatting.mediumDateTime(cert.validFrom))
                        detailRow("Valid Until", DateFormatting.mediumDateTime(cert.validUntil))
                    }
                }
            }
        }
    }

    private var pemSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "PEM Inspector")
                Text(endpoint.pemRepresentation ?? "No PEM available.")
                    .font(CertWatchTheme.monospaced(11))
                    .foregroundStyle(CertWatchTheme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button("Copy PEM") {
                        UIPasteboard.general.string = endpoint.pemRepresentation
                    }
                    .buttonStyle(.bordered)

                    if let pem = endpoint.pemRepresentation {
                        ShareLink(item: pem) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Check Status")
                detailRow("Last Checked", endpoint.lastCheckedAt.map(DateFormatting.mediumDateTime) ?? "Never")
                if let validFrom = endpoint.validFrom {
                    detailRow("Valid From", DateFormatting.mediumDateTime(validFrom))
                }
                if let validUntil = endpoint.validUntil {
                    detailRow("Valid Until", DateFormatting.mediumDateTime(validUntil))
                }
            }
        }
    }

    private var notesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Notes")
                TextField("Renew via Cloudflare…", text: $notesDraft, axis: .vertical)
                    .lineLimit(2...5)
                    .onSubmit { saveNotes() }
                Button("Save Notes") { saveNotes() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await refreshNow() }
            } label: {
                Label(isRefreshing ? "Checking…" : "Check Now", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(CertWatchTheme.healthy)
            .disabled(isRefreshing)

            Button(role: .destructive) {
                Task {
                    try? await store?.delete(endpoint)
                    dismiss()
                }
            } label: {
                Label("Remove", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(CertWatchTheme.critical)
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CertWatchTheme.tertiaryText)
            Text(value)
                .font(.body)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshNow() async {
        guard let store else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        do {
            try await store.refresh(endpoint)
            try modelContext.save()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveNotes() {
        try? store?.updateNotes(endpoint, notes: notesDraft)
    }
}
