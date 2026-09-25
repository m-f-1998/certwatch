import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published private(set) var purchaseError: String?
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
            purchaseError = nil
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchasePro() async -> Bool {
        guard let product else { return false }
        isPurchasing = true
        purchaseError = nil
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
        purchaseError = nil
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
        purchaseError = nil
        await finishUnfinishedTransactions()
        if AppSettings.isProUnlocked { return }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
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

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }
}
