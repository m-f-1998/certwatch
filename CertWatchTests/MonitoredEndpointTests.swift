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
}
