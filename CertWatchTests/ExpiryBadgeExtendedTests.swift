import XCTest
@testable import CertWatch

final class ExpiryBadgeExtendedTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 9))!

    private func endpoint(days: Int) -> MonitoredEndpoint {
        let endpoint = MonitoredEndpoint(hostname: "example.com", port: 443)
        endpoint.validUntil = calendar.date(byAdding: .day, value: days, to: now)
        endpoint.isReachable = true
        return endpoint
    }
    func testStatusDay0() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: -3), now: now)
        switch status {
        case .expired: break
        default: XCTFail("Expected expired for day -3")
        }
    }

    func testStatusDay1() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: -2), now: now)
        switch status {
        case .expired: break
        default: XCTFail("Expected expired for day -2")
        }
    }

    func testStatusDay2() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: -1), now: now)
        switch status {
        case .expired: break
        default: XCTFail("Expected expired for day -1")
        }
    }

    func testStatusDay3() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 0), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 0")
        }
    }

    func testStatusDay4() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 1), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 1")
        }
    }

    func testStatusDay5() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 2), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 2")
        }
    }

    func testStatusDay6() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 3), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 3")
        }
    }

    func testStatusDay7() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 4), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 4")
        }
    }

    func testStatusDay8() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 5), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 5")
        }
    }

    func testStatusDay9() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 6), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 6")
        }
    }

    func testStatusDay10() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 7), now: now)
        switch status {
        case .critical: break
        default: XCTFail("Expected critical for day 7")
        }
    }

    func testStatusDay11() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 8), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 8")
        }
    }

    func testStatusDay12() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 9), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 9")
        }
    }

    func testStatusDay13() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 10), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 10")
        }
    }

    func testStatusDay14() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 11), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 11")
        }
    }

    func testStatusDay15() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 12), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 12")
        }
    }

    func testStatusDay16() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 13), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 13")
        }
    }

    func testStatusDay17() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 14), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 14")
        }
    }

    func testStatusDay18() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 15), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 15")
        }
    }

    func testStatusDay19() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 16), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 16")
        }
    }

    func testStatusDay20() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 17), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 17")
        }
    }

    func testStatusDay21() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 18), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 18")
        }
    }

    func testStatusDay22() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 19), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 19")
        }
    }

    func testStatusDay23() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 20), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 20")
        }
    }

    func testStatusDay24() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 21), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 21")
        }
    }

    func testStatusDay25() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 22), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 22")
        }
    }

    func testStatusDay26() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 23), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 23")
        }
    }

    func testStatusDay27() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 24), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 24")
        }
    }

    func testStatusDay28() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 25), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 25")
        }
    }

    func testStatusDay29() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 26), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 26")
        }
    }

    func testStatusDay30() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 27), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 27")
        }
    }

    func testStatusDay31() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 28), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 28")
        }
    }

    func testStatusDay32() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 29), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 29")
        }
    }

    func testStatusDay33() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 30), now: now)
        switch status {
        case .warning: break
        default: XCTFail("Expected warning for day 30")
        }
    }

    func testStatusDay34() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 31), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 31")
        }
    }

    func testStatusDay35() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 32), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 32")
        }
    }

    func testStatusDay36() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 33), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 33")
        }
    }

    func testStatusDay37() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 34), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 34")
        }
    }

    func testStatusDay38() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 35), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 35")
        }
    }

    func testStatusDay39() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 36), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 36")
        }
    }

    func testStatusDay40() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 37), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 37")
        }
    }

    func testStatusDay41() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 38), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 38")
        }
    }

    func testStatusDay42() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 39), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 39")
        }
    }

    func testStatusDay43() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 40), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 40")
        }
    }

    func testStatusDay44() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 41), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 41")
        }
    }

    func testStatusDay45() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 42), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 42")
        }
    }

    func testStatusDay46() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 43), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 43")
        }
    }

    func testStatusDay47() {
        let status = ExpiryBadgeStyle.status(for: endpoint(days: 44), now: now)
        switch status {
        case .healthy: break
        default: XCTFail("Expected healthy for day 44")
        }
    }

}