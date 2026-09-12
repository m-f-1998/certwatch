import XCTest
@testable import CertWatch

final class NotificationSchedulerTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
    }

    private func endpoint(validUntil: Date) -> MonitoredEndpoint {
        let endpoint = MonitoredEndpoint(hostname: "api.example.com", port: 443)
        endpoint.validUntil = validUntil
        endpoint.isReachable = true
        return endpoint
    }

    func testNotificationIDIsDeterministic() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(NotificationScheduler.notificationID(endpointID: id, threshold: 7), "\(id.uuidString)-7")
    }

    func testParseNotificationIDRoundTrip() {
        let id = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let identifier = NotificationScheduler.notificationID(endpointID: id, threshold: 30)
        let parsed = NotificationScheduler.parseNotificationID(identifier)
        XCTAssertEqual(parsed?.endpointID, id)
        XCTAssertEqual(parsed?.threshold, 30)
    }

    func testParseNotificationIDRejectsNonCertWatchIdentifiers() {
        XCTAssertNil(NotificationScheduler.parseNotificationID("some-other-notification"))
        XCTAssertNil(NotificationScheduler.parseNotificationID("not-a-uuid-30"))
    }

    func testNotificationBodyIncludesHostThresholdAndDate() {
        let validUntil = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17))!
        let endpoint = endpoint(validUntil: validUntil)
        let body = NotificationScheduler.notificationBody(for: endpoint, validUntil: validUntil, threshold: 7)
        XCTAssertTrue(body.contains("api.example.com"))
        XCTAssertTrue(body.contains("7 days"))
        XCTAssertTrue(body.contains("2026"))
    }

    func testNotificationBodySingularDayGrammar() {
        let validUntil = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17))!
        let endpoint = endpoint(validUntil: validUntil)
        let body = NotificationScheduler.notificationBody(for: endpoint, validUntil: validUntil, threshold: 1)
        XCTAssertTrue(body.contains("1 day"))
        XCTAssertFalse(body.contains("1 days"))
    }

    func testFireDateThirtyDaysBeforeExpiry() {
        let validUntil = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        let fireDate = calendar.date(byAdding: .day, value: -30, to: validUntil)!
        XCTAssertEqual(calendar.component(.day, from: fireDate), 1)
        XCTAssertEqual(calendar.component(.month, from: fireDate), 11)
    }

    func testThresholdSchedulingSkipsPastDates() {
        let validUntil = calendar.date(byAdding: .day, value: 10, to: now)!
        let thresholds = [30, 14, 7, 1]
        let validThresholds = thresholds.filter { threshold in
            guard let fireDate = calendar.date(byAdding: .day, value: -threshold, to: validUntil) else { return false }
            return fireDate > now
        }
        XCTAssertEqual(validThresholds, [7, 1])
    }

    func testThresholdMatrixProducesExpectedCounts() {
        let validUntil = calendar.date(byAdding: .day, value: 100, to: now)!
        let thresholds = [90, 60, 30, 14, 7, 1]
        let count = thresholds.filter { threshold in
            guard let fireDate = calendar.date(byAdding: .day, value: -threshold, to: validUntil) else { return false }
            return fireDate > now
        }.count
        XCTAssertEqual(count, 6)
    }
}
