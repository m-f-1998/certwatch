import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var purchaseInfo: String?
    @Published private(set) var storefrontCountryCode: String?

    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { @MainActor in
            await observeTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        await finishUnfinishedTransactions()
        let countryCode = await Storefront.current?.countryCode
        do {
            let products = try await Product.products(for: [AppSettings.proProductID])
            storefrontCountryCode = countryCode
            product = products.first
            clearPurchaseFeedback()
        } catch {
            purchaseError = error.localizedDescription
            purchaseInfo = nil
        }
    }

    func purchasePro() async -> Bool {
        guard let product else { return false }
        isPurchasing = true
        clearPurchaseFeedback()
        defer { isPurchasing = false }

        await finishUnfinishedTransactions()
        if AppSettings.isProUnlocked { return true }

        do {
            let result = try await product.purchase()
            return await completePurchase(result)
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func completePurchase(_ result: Product.PurchaseResult) async -> Bool {
        clearPurchaseFeedback()
        switch result {
        case .success(let verification):
            do {
                let transaction = try checkVerified(verification)
                await transaction.finish()
                AppSettings.unlockPro()
                await NotificationRescheduleService.rescheduleAll()
                BackgroundRefreshService.scheduleNextRefresh()
                return true
            } catch {
                purchaseError = error.localizedDescription
                return false
            }
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        isRestoring = true
        clearPurchaseFeedback()
        defer { isRestoring = false }

        await finishUnfinishedTransactions()
        if AppSettings.isProUnlocked { return }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !AppSettings.isProUnlocked {
                purchaseInfo = "No previous purchases were found for this Apple ID."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == AppSettings.proProductID {
                AppSettings.unlockPro()
                await NotificationRescheduleService.rescheduleAll()
                BackgroundRefreshService.scheduleNextRefresh()
                return
            }
        }
    }

    private func finishUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                if transaction.productID == AppSettings.proProductID {
                    AppSettings.unlockPro()
                    await NotificationRescheduleService.rescheduleAll()
                    BackgroundRefreshService.scheduleNextRefresh()
                }
                await transaction.finish()
            case .unverified(let transaction, _):
                await transaction.finish()
            }
        }
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                if transaction.productID == AppSettings.proProductID {
                    AppSettings.unlockPro()
                    await NotificationRescheduleService.rescheduleAll()
                    BackgroundRefreshService.scheduleNextRefresh()
                }
                await transaction.finish()
            case .unverified(let transaction, _):
                await transaction.finish()
            }
        }
    }

    private func clearPurchaseFeedback() {
        purchaseError = nil
        purchaseInfo = nil
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
}
