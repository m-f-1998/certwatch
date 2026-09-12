import XCTest
@testable import CertWatch

final class MonitoredEndpointTests: XCTestCase {
    func testTitlePrefersDisplayName() {
        let endpoint = MonitoredEndpoint(hostname: "host.test", port: 443, displayName: "Production")
        XCTAssertEqual(endpoint.title, "Production")
    }

    func testHostPortLabelOmitsDefaultPort() {
        let endpoint = MonitoredEndpoint(hostname: "host.test", port: 443)
        XCTAssertEqual(endpoint.hostPortLabel, "host.test")

        endpoint.port = 8443
        XCTAssertEqual(endpoint.hostPortLabel, "host.test:8443")
    }

    func testApplyCertificateUpdatesCachedFields() {
        let endpoint = MonitoredEndpoint(hostname: "api.example.com", port: 443)
        let certificate = CertificateInfo.preview()
        endpoint.apply(certificate: certificate)

        XCTAssertTrue(endpoint.isReachable)
        XCTAssertNil(endpoint.lastError)
        XCTAssertEqual(endpoint.subjectCN, "api.example.com")
        XCTAssertEqual(endpoint.issuerCN, "Let's Encrypt R3")
        XCTAssertNotNil(endpoint.pemData)
        XCTAssertEqual(endpoint.subjectAlternativeNames, ["api.example.com", "www.example.com"])
    }

    func testApplyErrorMarksUnreachable() {
        let endpoint = MonitoredEndpoint(hostname: "bad.test", port: 443)
        endpoint.apply(error: "Connection failed")
        XCTAssertFalse(endpoint.isReachable)
        XCTAssertEqual(endpoint.lastError, "Connection failed")
    }

    func testApplyUsesLeafExpiryNotIntermediate() {
        let now = Date()
        let leafExpiry = now.addingTimeInterval(78 * 86_400)
        let intermediateExpiry = now.addingTimeInterval(892 * 86_400 + 3_600)

        let intermediate = CertificateInfo(
            subjectCommonName: "WE1",
            subjectAlternativeNames: [],
            issuerCommonName: "GTS Root R4",
            validFrom: now.addingTimeInterval(-365 * 86_400),
            validUntil: intermediateExpiry,
            serialNumber: "INT",
            signatureAlgorithm: "SHA-256 with RSA Encryption",
            publicKeyDescription: "RSA (2048 bits)",
            pemRepresentation: "-----BEGIN CERTIFICATE-----\nINTERMEDIATE\n-----END CERTIFICATE-----",
            chain: []
        )

        let chainRoot = CertificateInfo(
            subjectCommonName: "cloudflare.com",
            subjectAlternativeNames: ["cloudflare.com"],
            issuerCommonName: "WE1",
            validFrom: now.addingTimeInterval(-30 * 86_400),
            validUntil: leafExpiry,
            serialNumber: "LEAF",
            signatureAlgorithm: "ECDSA with SHA-256",
            publicKeyDescription: "EC (256 bits)",
            pemRepresentation: "-----BEGIN CERTIFICATE-----\nLEAF\n-----END CERTIFICATE-----",
            chain: [intermediate]
        )

        let endpoint = MonitoredEndpoint(hostname: "cloudflare.com", port: 443)
        endpoint.apply(certificate: chainRoot)

        XCTAssertEqual(endpoint.validUntil, leafExpiry)
        XCTAssertEqual(endpoint.subjectCN, "cloudflare.com")
        XCTAssertNotEqual(endpoint.validUntil, intermediateExpiry)

        let chain = endpoint.chainCertificates
        XCTAssertEqual(chain.count, 2)
        XCTAssertEqual(chain[0].subjectCommonName, "cloudflare.com")
        XCTAssertEqual(chain[1].subjectCommonName, "WE1")
    }
}
