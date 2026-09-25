import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKitManager: StoreKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("CertWatch Pro")
                        .font(.largeTitle.bold())

                    Text("Unlock unlimited monitoring, widgets, custom alerts, and export/import.")
                        .foregroundStyle(CertWatchTheme.secondaryText)

                    featureRow("infinity", "Unlimited endpoints")
                    featureRow("link", "Full certificate chain inspector")
                    featureRow("bell.badge", "Custom alert thresholds")
                    featureRow("rectangle.grid.2x2", "Home Screen widgets")
                    featureRow("arrow.clockwise.circle", "Daily background refresh")
                    featureRow("tag", "Tags, notes, and export/import")

                    if let product = storeKitManager.product {
                        Text("One-time purchase · \(product.localizedDisplayPrice(storefrontCountryCode: storeKitManager.storefrontCountryCode))")
                            .font(.title3.bold())
                            .padding(.top, 8)
                    }

                    if let error = storeKitManager.purchaseError {
                        purchaseErrorBanner(error)
                    }

                    Button {
                        Task {
                            if await storeKitManager.purchasePro() {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if storeKitManager.isPurchasing {
                                Text("Purchasing…")
                            } else {
                                Text("Unlock Pro")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CertWatchTheme.healthy)
                    .disabled(storeKitManager.isPurchasing)

                    Button("Restore Purchases") {
                        Task {
                            await storeKitManager.restorePurchases()
                            if AppSettings.isProUnlocked {
                                dismiss()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            .safeAreaPadding(.bottom)
            .background(CertWatchTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await storeKitManager.loadProducts()
                if AppSettings.isProUnlocked {
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func purchaseErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.medium)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(CertWatchTheme.critical)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CertWatchTheme.critical.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func featureRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(CertWatchTheme.healthy)
                .frame(width: 24)
            Text(text)
        }
    }
}
