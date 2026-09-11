import XCTest
@testable import CertWatch

final class ExportImportTests: XCTestCase {
    func testExportImportRoundTrip() throws {
        let endpoint = MonitoredEndpoint(
            hostname: "api.example.com",
            port: 8443,
            displayName: "Production API",
            tag: "Production",
            notes: "Renew via Cloudflare"
        )

        let data = try ExportImportService.export(endpoints: [endpoint])
        let decoded = try ExportImportService.decode(data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.endpoints.count, 1)
        XCTAssertEqual(decoded.endpoints[0].hostname, "api.example.com")
        XCTAssertEqual(decoded.endpoints[0].port, 8443)
        XCTAssertEqual(decoded.endpoints[0].displayName, "Production API")
        XCTAssertEqual(decoded.endpoints[0].tag, "Production")
        XCTAssertEqual(decoded.endpoints[0].notes, "Renew via Cloudflare")
    }

    func testExportProducesPrettyPrintedJSON() throws {
        let endpoint = MonitoredEndpoint(hostname: "example.com", port: 443)
        let data = try ExportImportService.export(endpoints: [endpoint])
        let string = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(string.contains("\n"))
        XCTAssertTrue(string.contains("\"version\""))
    }

    func testDecodeRejectsInvalidJSON() {
        XCTAssertThrowsError(try ExportImportService.decode(Data("not-json".utf8)))
    }

    func testExportEmptyList() throws {
        let data = try ExportImportService.export(endpoints: [])
        let decoded = try ExportImportService.decode(data)
        XCTAssertTrue(decoded.endpoints.isEmpty)
    }
}
