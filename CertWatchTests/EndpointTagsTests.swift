import XCTest
@testable import CertWatch

final class EndpointTagsTests: XCTestCase {
    func testNormalizeTrimsAndRejectsEmpty() {
        XCTAssertEqual(EndpointTags.normalize("  Production  "), "Production")
        XCTAssertNil(EndpointTags.normalize("   "))
    }

    func testNormalizeEnforcesMaxLength() {
        let long = String(repeating: "a", count: 40)
        XCTAssertEqual(EndpointTags.normalize(long)?.count, EndpointTags.maxLength)
    }

    func testPickerOptionsPrefersInUseTagsFirst() {
        let production = MonitoredEndpoint(hostname: "a.test", port: 443, tag: "Production")
        let staging = MonitoredEndpoint(hostname: "b.test", port: 443, tag: "Staging")
        let options = EndpointTags.pickerOptions(from: [production, staging])
        XCTAssertEqual(options.prefix(2), ["Production", "Staging"])
        XCTAssertTrue(options.contains("Development"))
    }

    func testDisplayOptionsIncludesSelectionNotInBase() {
        let options = EndpointTags.displayOptions(base: ["Production"], including: "My Client")
        XCTAssertEqual(options, ["My Client", "Production"])
    }

    func testRememberPersistsCustomTagInPickerOptions() {
        EndpointTags.remember("My Client")
        let options = EndpointTags.pickerOptions(from: [])
        XCTAssertTrue(options.contains("My Client"))
        EndpointTags.removeFromCatalog("My Client")
    }

    func testRemoveFromCatalogHidesTagUntilRememberedAgain() {
        EndpointTags.remember("Archive")
        EndpointTags.removeFromCatalog("Archive")
        XCTAssertFalse(EndpointTags.pickerOptions(from: []).contains("Archive"))

        EndpointTags.remember("Archive")
        XCTAssertTrue(EndpointTags.pickerOptions(from: []).contains("Archive"))
        EndpointTags.removeFromCatalog("Archive")
    }

    func testFilterOptionsCountsTags() {
        let endpoints = [
            MonitoredEndpoint(hostname: "a.test", port: 443, tag: "Production"),
            MonitoredEndpoint(hostname: "b.test", port: 443, tag: "Production"),
            MonitoredEndpoint(hostname: "c.test", port: 443, tag: "Staging")
        ]
        let filters = EndpointTags.filterOptions(from: endpoints)
        XCTAssertEqual(filters.count, 2)
        XCTAssertEqual(filters[0].name, "Production")
        XCTAssertEqual(filters[0].count, 2)
        XCTAssertEqual(filters[1].name, "Staging")
        XCTAssertEqual(filters[1].count, 1)
    }
}
