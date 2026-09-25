import StoreKit

extension Product {
    /// Price in the customer's currency. StoreKit often labels a UK price as USD; the phone region and App Store storefront correct that without pinning every country to pounds.
    func localizedDisplayPrice(storefrontCountryCode: String?) -> String {
        let code = resolvedCurrencyCode(storefrontCountryCode: storefrontCountryCode)
        let locale = locale(for: code, storefrontCountryCode: storefrontCountryCode)
        return price.formatted(.currency(code: code).locale(locale))
    }

    private func resolvedCurrencyCode(storefrontCountryCode: String?) -> String {
        let storefrontCurrency = currencyCode(forCountry: storefrontCountryCode)
        let deviceCurrency = currencyCode(forCountry: Locale.current.region?.identifier)
        if let storefrontCurrency, storefrontCurrency != "USD" {
            return storefrontCurrency
        }
        if let deviceCurrency, deviceCurrency != "USD" {
            return deviceCurrency
        }
        return storefrontCurrency ?? priceFormatStyle.currencyCode
    }

    private func locale(for currency: String, storefrontCountryCode: String?) -> Locale {
        let countries = [storefrontCountryCode, Locale.current.region?.identifier].compactMap { $0 }
        for country in countries {
            let locale = Locale(components: Locale.Components(
                languageCode: "en",
                languageRegion: Locale.Region(country)
            ))
            if locale.currency?.identifier == currency {
                return locale
            }
        }
        return .current
    }

    private func currencyCode(forCountry countryCode: String?) -> String? {
        guard let countryCode, !countryCode.isEmpty else { return nil }
        let locale = Locale(components: Locale.Components(
            languageCode: "en",
            languageRegion: Locale.Region(countryCode)
        ))
        return locale.currency?.identifier
    }
}
