import XCTest
@testable import CertWatch

final class HostnameParserExtendedTests: XCTestCase {
    func testValidHost0() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("a.co"))
    }

    func testValidHost1() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("abc.example.com"))
    }

    func testValidHost2() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("my-site.io"))
    }

    func testValidHost3() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("x.y.z.w.example.com"))
    }

    func testValidHost4() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("1.example.com"))
    }

    func testValidHost5() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("a1.b2.c3.d4.example.com"))
    }

    func testValidHost6() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("test.local"))
    }

    func testValidHost7() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("host.internal"))
    }

    func testValidHost8() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("api.v2.example.com"))
    }

    func testValidHost9() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("cdn-1.example.net"))
    }

    func testValidHost10() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("a.b"))
    }

    func testValidHost11() throws {
        XCTAssertTrue(HostnameParser.isValidHostname("zz.top"))
    }

    func testValidPort0() {
        XCTAssertTrue(HostnameParser.isValidPort(1))
    }

    func testValidPort1() {
        XCTAssertTrue(HostnameParser.isValidPort(80))
    }

    func testValidPort2() {
        XCTAssertTrue(HostnameParser.isValidPort(443))
    }

    func testValidPort3() {
        XCTAssertTrue(HostnameParser.isValidPort(8443))
    }

    func testValidPort4() {
        XCTAssertTrue(HostnameParser.isValidPort(9443))
    }

    func testValidPort5() {
        XCTAssertTrue(HostnameParser.isValidPort(3000))
    }

    func testValidPort6() {
        XCTAssertTrue(HostnameParser.isValidPort(8080))
    }

    func testValidPort7() {
        XCTAssertTrue(HostnameParser.isValidPort(65535))
    }

    func testInvalidPort0() {
        XCTAssertFalse(HostnameParser.isValidPort(0))
    }

    func testInvalidPort1() {
        XCTAssertFalse(HostnameParser.isValidPort(-1))
    }

    func testInvalidPort2() {
        XCTAssertFalse(HostnameParser.isValidPort(65536))
    }

    func testInvalidPort3() {
        XCTAssertFalse(HostnameParser.isValidPort(99999))
    }

    func testParseCase0() throws {
        let parsed = try HostnameParser.parse("https://foo:8443/bar").get()
        XCTAssertEqual(parsed.hostname, "foo")
        XCTAssertEqual(parsed.port, 8443)
    }

    func testParseCase1() throws {
        let parsed = try HostnameParser.parse("http://bar:8080").get()
        XCTAssertEqual(parsed.hostname, "bar")
        XCTAssertEqual(parsed.port, 8080)
    }

    func testParseCase2() throws {
        let parsed = try HostnameParser.parse("baz.test:9443").get()
        XCTAssertEqual(parsed.hostname, "baz.test")
        XCTAssertEqual(parsed.port, 9443)
    }

    func testParseCase3() throws {
        let parsed = try HostnameParser.parse("https://cdn.example.com").get()
        XCTAssertEqual(parsed.hostname, "cdn.example.com")
        XCTAssertEqual(parsed.port, 443)
    }

}