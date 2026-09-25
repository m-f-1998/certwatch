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
                        feedbackBanner(error, style: .error)
                    } else if let info = storeKitManager.purchaseInfo {
                        feedbackBanner(info, style: .info)
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
                    .disabled(storeKitManager.isPurchasing || storeKitManager.isRestoring)

                    Button {
                        Task {
                            await storeKitManager.restorePurchases()
                            if AppSettings.isProUnlocked {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if storeKitManager.isRestoring {
                                Text("Restoring…")
                            } else {
                                Text("Restore Purchases")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(storeKitManager.isPurchasing || storeKitManager.isRestoring)
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

    private enum FeedbackStyle {
        case error
        case info

        var symbol: String {
            switch self {
            case .error: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .error: CertWatchTheme.critical
            case .info: CertWatchTheme.secondaryText
            }
        }
    }

    private func feedbackBanner(_ message: String, style: FeedbackStyle) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.symbol)
                .imageScale(.medium)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote)
        .foregroundStyle(style.color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.color.opacity(0.12))
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
