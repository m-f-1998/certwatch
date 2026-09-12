import StoreKit

extension Product {
    /// Storefront price string from App Store / StoreKit testing — same value shown on the purchase sheet.
    var localizedDisplayPrice: String {
        displayPrice
    }
}
