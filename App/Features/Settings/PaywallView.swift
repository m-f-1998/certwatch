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
                    featureRow("bell.badge", "Custom alert thresholds")
                    featureRow("rectangle.grid.2x2", "Home Screen widgets")
                    featureRow("arrow.clockwise.circle", "Daily background refresh")
                    featureRow("tag", "Tags, notes, and export/import")

                    if let product = storeKitManager.product {
                        Text(product.displayPrice)
                            .font(.title2.bold())
                            .padding(.top, 8)
                    }

                    Button {
                        Task {
                            if await storeKitManager.purchasePro() {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(storeKitManager.isPurchasing ? "Purchasing…" : "Unlock Pro")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CertWatchTheme.healthy)
                    .disabled(storeKitManager.isPurchasing)

                    Button("Restore Purchases") {
                        Task { await storeKitManager.restorePurchases() }
                    }
                    .frame(maxWidth: .infinity)

                    if let error = storeKitManager.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(CertWatchTheme.critical)
                    }
                }
                .padding()
            }
            .background(CertWatchTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
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
