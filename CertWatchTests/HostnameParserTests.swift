import XCTest
@testable import CertWatch

final class HostnameParserTests: XCTestCase {
    func testParseEmptyInputFails() {
        XCTAssertEqual(HostnameParser.parse(""), .failure(.empty))
        XCTAssertEqual(HostnameParser.parse("   "), .failure(.empty))
    }

    func testParseSimpleHostnameUsesDefaultPort() throws {
        let parsed = try HostnameParser.parse("api.example.com").get()
        XCTAssertEqual(parsed.hostname, "api.example.com")
        XCTAssertEqual(parsed.port, 443)
    }

    func testParseHostnameWithExplicitPort() throws {
        let parsed = try HostnameParser.parse("api.example.com:8443").get()
        XCTAssertEqual(parsed.hostname, "api.example.com")
        XCTAssertEqual(parsed.port, 8443)
    }

    func testParseHTTPSURLIgnoresPath() throws {
        let parsed = try HostnameParser.parse("https://api.example.com:8443/v1/health").get()
        XCTAssertEqual(parsed.hostname, "api.example.com")
        XCTAssertEqual(parsed.port, 8443)
    }

    func testParseHTTPURLUsesExplicitPort() throws {
        let parsed = try HostnameParser.parse("http://localhost:8080").get()
        XCTAssertEqual(parsed.hostname, "localhost")
        XCTAssertEqual(parsed.port, 8080)
    }

    func testParseNormalizesHostnameCase() throws {
        let parsed = try HostnameParser.parse("API.Example.COM").get()
        XCTAssertEqual(parsed.hostname, "api.example.com")
    }

    func testParseIPv4Address() throws {
        let parsed = try HostnameParser.parse("192.168.0.10:4443").get()
        XCTAssertEqual(parsed.hostname, "192.168.0.10")
        XCTAssertEqual(parsed.port, 4443)
    }

    func testParseBracketedIPv6WithoutPort() throws {
        let parsed = try HostnameParser.parse("[2001:db8::1]").get()
        XCTAssertEqual(parsed.hostname, "2001:db8::1")
        XCTAssertEqual(parsed.port, 443)
    }

    func testParseBracketedIPv6WithPort() throws {
        let parsed = try HostnameParser.parse("[2001:db8::1]:8443").get()
        XCTAssertEqual(parsed.hostname, "2001:db8::1")
        XCTAssertEqual(parsed.port, 8443)
    }

    func testInvalidPortZeroFails() {
        XCTAssertEqual(HostnameParser.parse("example.com:0"), .failure(.invalidPort))
    }

    func testInvalidPortTooLargeFails() {
        XCTAssertEqual(HostnameParser.parse("example.com:70000"), .failure(.invalidPort))
    }

    func testInvalidHostnameWithSpacesFails() {
        XCTAssertEqual(HostnameParser.parse("not a host"), .failure(.invalidHost))
    }

    func testInvalidHostnameLeadingHyphenFails() {
        XCTAssertFalse(HostnameParser.isValidHostname("-bad.example.com"))
    }

    func testValidPortBoundaries() {
        XCTAssertTrue(HostnameParser.isValidPort(1))
        XCTAssertTrue(HostnameParser.isValidPort(65535))
        XCTAssertFalse(HostnameParser.isValidPort(0))
        XCTAssertFalse(HostnameParser.isValidPort(65536))
    }

    func testHostnameParserMatrix() throws {
        let cases: [(String, String, Int)] = [
            ("example.com", "example.com", 443),
            ("sub.domain.co.uk", "sub.domain.co.uk", 443),
            ("https://example.com", "example.com", 443),
            ("https://example.com:9443", "example.com", 9443),
            ("host.test:1", "host.test", 1),
            ("127.0.0.1", "127.0.0.1", 443),
            ("127.0.0.1:8443", "127.0.0.1", 8443)
        ]

        for (input, host, port) in cases {
            let parsed = try HostnameParser.parse(input).get()
            XCTAssertEqual(parsed.hostname, host, "Failed host for \(input)")
            XCTAssertEqual(parsed.port, port, "Failed port for \(input)")
        }
    }

    func testUnsupportedURLSchemeFails() {
        XCTAssertEqual(
            HostnameParser.parse("ftp://files.example.com"),
            .failure(.unsupportedScheme("ftp"))
        )
    }

    func testURLWithCredentialsFails() {
        if case .success = HostnameParser.parse("https://user:pass@example.com") {
            XCTFail("Expected credentials in URL to fail")
        }
    }

    func testInvalidHostnameMatrix() {
        let invalid = [
            "",
            " ",
            "bad host",
            "bad..example.com",
            "example.com:abc",
            "https://",
            "://missing",
            "toolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabeltoolonglabel.example.com"
        ]

        for input in invalid {
            if case .success = HostnameParser.parse(input) {
                XCTFail("Expected failure for \(input)")
            }
        }
    }

    func testDefaultPortOverride() throws {
        let parsed = try HostnameParser.parse("example.com", defaultPort: 8443).get()
        XCTAssertEqual(parsed.port, 8443)
    }
}
