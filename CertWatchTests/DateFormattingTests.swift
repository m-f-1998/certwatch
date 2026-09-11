import XCTest
@testable import CertWatch

final class DateFormattingTests: XCTestCase {
    func testRelativeDaysAndHoursFutureDate() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let future = now.addingTimeInterval(2 * 86_400 + 3 * 3_600)
        let text = DateFormatting.relativeDaysAndHours(until: future, from: now)
        XCTAssertTrue(text.contains("2 days"))
        XCTAssertTrue(text.contains("3 hours"))
    }

    func testRelativeDaysAndHoursExpired() {
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        XCTAssertEqual(DateFormatting.relativeDaysAndHours(until: past, from: now), "Expired")
    }

    func testMediumDateFormatsWithoutCrashing() {
        let formatted = DateFormatting.mediumDate(Date())
        XCTAssertFalse(formatted.isEmpty)
    }
}
