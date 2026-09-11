import XCTest
@testable import CertWatch

final class CertificatePEMParserTests: XCTestCase {
    func testDecodeInvalidPEMReturnsNil() {
        XCTAssertNil(CertificatePEMParser.decodePEM("not a pem"))
    }

    func testParseMultipleReturnsEmptyForInvalidInput() {
        XCTAssertTrue(CertificatePEMParser.parseMultiple(from: "invalid").isEmpty)
    }

    func testDecodeStripsHeadersAndWhitespace() {
        let pem = """
        -----BEGIN CERTIFICATE-----
        QUJDR
        UY=
        -----END CERTIFICATE-----
        """
        let data = CertificatePEMParser.decodePEM(pem)
        XCTAssertEqual(data, Data(base64Encoded: "QUJDRUY="))
    }
}
