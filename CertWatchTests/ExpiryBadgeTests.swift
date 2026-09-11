import XCTest
@testable import CertWatch

final class ExpiryBadgeTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    }

    private func makeEndpoint(validUntil: Date?, reachable: Bool = true) -> MonitoredEndpoint {
        let endpoint = MonitoredEndpoint(hostname: "example.com", port: 443)
        endpoint.validUntil = validUntil
        endpoint.isReachable = reachable
        return endpoint
    }

    func testDaysRemainingUsesStartOfDay() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        XCTAssertEqual(ExpiryBadgeStyle.daysRemaining(until: tomorrow, from: now), 1)
    }

    func testStatusHealthyBeyondThirtyDays() {
        let expiry = calendar.date(byAdding: .day, value: 45, to: now)!
        let endpoint = makeEndpoint(validUntil: expiry)
        XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), .healthy)
    }

    func testStatusWarningBetweenEightAndThirtyDays() {
        let expiry = calendar.date(byAdding: .day, value: 20, to: now)!
        let endpoint = makeEndpoint(validUntil: expiry)
        XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), .warning)
    }

    func testStatusCriticalWithinSevenDays() {
        let expiry = calendar.date(byAdding: .day, value: 5, to: now)!
        let endpoint = makeEndpoint(validUntil: expiry)
        XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), .critical)
    }

    func testStatusExpiredWhenPastDate() {
        let expiry = calendar.date(byAdding: .day, value: -1, to: now)!
        let endpoint = makeEndpoint(validUntil: expiry)
        XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), .expired)
    }

    func testStatusUnreachableWithoutExpiry() {
        let endpoint = makeEndpoint(validUntil: nil, reachable: false)
        XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), .unreachable)
    }

    func testPillTextFormatsDaysAndExpired() {
        let expiry = calendar.date(byAdding: .day, value: 12, to: now)!
        let endpoint = makeEndpoint(validUntil: expiry)
        XCTAssertEqual(ExpiryBadgeStyle.pillText(for: endpoint, now: now), "12d")

        let expired = calendar.date(byAdding: .day, value: -2, to: now)!
        endpoint.validUntil = expired
        XCTAssertEqual(ExpiryBadgeStyle.pillText(for: endpoint, now: now), "EXP")
    }

    func testValidityProgressClamps() {
        let from = calendar.date(byAdding: .day, value: -90, to: now)!
        let until = calendar.date(byAdding: .day, value: 90, to: now)!
        let progress = ExpiryBadgeStyle.validityProgress(validFrom: from, validUntil: until, now: now)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    func testThresholdBoundaries() {
        let boundaries: [(Int, ExpiryStatus)] = [
            (31, .healthy),
            (30, .warning),
            (8, .warning),
            (7, .critical),
            (0, .critical),
            (-1, .expired)
        ]

        for (offset, expected) in boundaries {
            let expiry = calendar.date(byAdding: .day, value: offset, to: now)!
            let endpoint = makeEndpoint(validUntil: expiry)
            XCTAssertEqual(ExpiryBadgeStyle.status(for: endpoint, now: now), expected, "Offset \(offset)")
        }
    }

    func testSortByExpiryOrdersSoonestFirst() {
        let later = makeEndpoint(validUntil: calendar.date(byAdding: .day, value: 40, to: now))
        let sooner = makeEndpoint(validUntil: calendar.date(byAdding: .day, value: 5, to: now))
        let missing = makeEndpoint(validUntil: nil, reachable: false)

        let sorted = MonitoredEndpoint.sortByExpiry([later, missing, sooner])
        XCTAssertEqual(sorted.map(\.validUntil), [sooner.validUntil, later.validUntil, nil])
    }
}
