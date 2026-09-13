import Foundation
import SwiftData

enum AppStoreScreenshotScene: String, CaseIterable {
    case dashboard
    case detail
    case settings
}

enum AppStoreScreenshotSupport {
    static let launchFlag = "-AppStoreScreenshot"

    static func scene(from arguments: [String]) -> AppStoreScreenshotScene? {
        guard let index = arguments.firstIndex(of: launchFlag),
              arguments.indices.contains(index + 1),
              let scene = AppStoreScreenshotScene(rawValue: arguments[index + 1]) else {
            return nil
        }
        return scene
    }

    static func configureForCapture() {
        AppSettings.isProUnlocked = true
        AppSettings.hasCompletedOnboarding = true
        AppSettings.notificationThresholds = AppSettings.defaultThresholds
        AppSettings.backgroundRefreshEnabled = true
    }

    static func makeSeededContainer() throws -> ModelContainer {
        let container = try ModelContainerFactory.makeContainer(inMemory: true)
        let context = ModelContext(container)

        let calendar = Calendar.current
        let now = Date()

        struct Sample {
            let hostname: String
            let port: Int
            let displayName: String?
            let tag: String?
            let daysRemaining: Int
            let issuer: String
        }

        let samples = [
            Sample(hostname: "api.matthewfrankland.com", port: 443, displayName: "Production API", tag: "Production", daysRemaining: 47, issuer: "Let's Encrypt"),
            Sample(hostname: "shop.acme.io", port: 443, displayName: nil, tag: "E-commerce", daysRemaining: 12, issuer: "DigiCert Inc"),
            Sample(hostname: "staging.internal.dev", port: 8443, displayName: "Staging", tag: "Internal", daysRemaining: 89, issuer: "Amazon"),
            Sample(hostname: "mail.example.org", port: 443, displayName: "Mail Server", tag: nil, daysRemaining: 6, issuer: "Google Trust Services"),
        ]

        for sample in samples {
            let endpoint = MonitoredEndpoint(
                hostname: sample.hostname,
                port: sample.port,
                displayName: sample.displayName,
                tag: sample.tag,
                notes: sample.tag == "Production" ? "Primary customer-facing API" : nil
            )
            endpoint.isReachable = true
            endpoint.lastCheckedAt = now
            endpoint.subjectCN = sample.hostname
            endpoint.issuerCN = sample.issuer
            endpoint.validFrom = calendar.date(byAdding: .day, value: -365 + sample.daysRemaining, to: now)
            endpoint.validUntil = calendar.date(byAdding: .day, value: sample.daysRemaining, to: now)
            endpoint.serialNumber = "04:A1:B2:C3:D4"
            endpoint.signatureAlgorithm = "SHA256withRSA"
            endpoint.publicKeyDescription = "EC (256 bits)"
            endpoint.sanSummary = "\(sample.hostname), www.\(sample.hostname)"
            endpoint.chainPEMData = Data("-----BEGIN CERTIFICATE-----\nMOCK\n-----END CERTIFICATE-----".utf8)
            context.insert(endpoint)
        }

        try context.save()
        return container
    }
}
