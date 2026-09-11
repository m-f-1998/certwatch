import XCTest
@testable import CertWatch

final class AppSettingsTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        AppSettings.isProUnlocked = false
        AppSettings.notificationThresholds = AppSettings.defaultThresholds
        AppSettings.defaultCheckPort = 443
        AppSettings.backgroundRefreshEnabled = false
    }

    func testFreeTierEndpointLimit() {
        AppSettings.isProUnlocked = false
        XCTAssertEqual(AppSettings.endpointLimit, 5)
    }

    func testProTierEndpointLimitIsUnlimited() {
        AppSettings.isProUnlocked = true
        XCTAssertEqual(AppSettings.endpointLimit, Int.max)
    }

    func testFreeThresholdDefaultsToThirtyDays() {
        AppSettings.isProUnlocked = false
        AppSettings.notificationThresholds = []
        XCTAssertEqual(AppSettings.notificationThresholds, [30])
    }

    func testProThresholdDefaultsIncludeMultipleValues() {
        AppSettings.isProUnlocked = true
        AppSettings.notificationThresholds = []
        XCTAssertEqual(AppSettings.notificationThresholds, AppSettings.defaultThresholds)
    }

    func testDefaultCheckPortFallback() {
        AppSettings.defaultCheckPort = 0
        XCTAssertEqual(AppSettings.defaultCheckPort, 443)
    }
}
