import XCTest
@testable import CertWatch

final class CertificateServiceErrorTests: XCTestCase {
    func testCertErrorDescriptions() {
        XCTAssertEqual(
            CertificateService.CertError.connectionFailed("refused").errorDescription,
            "Connection failed: refused"
        )
        XCTAssertEqual(
            CertificateService.CertError.noCertificatePresented.errorDescription,
            "No server certificate presented during TLS handshake."
        )
        XCTAssertEqual(
            CertificateService.CertError.invalidHost.errorDescription,
            "Invalid hostname or IP address."
        )
        XCTAssertEqual(
            CertificateService.CertError.timeout.errorDescription,
            "Connection timed out after 10 seconds."
        )
    }

    func testEndpointStoreErrorsAreLocalized() {
        XCTAssertTrue(EndpointStoreError.limitReached.errorDescription?.contains("5") == true)
        XCTAssertEqual(
            EndpointStoreError.duplicate.errorDescription,
            "This hostname and port is already being monitored."
        )
    }
}
