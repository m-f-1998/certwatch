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

    func testUnlockProMigratesFreeThresholdsToDefaults() {
        AppSettings.isProUnlocked = false
        AppSettings.notificationThresholds = AppSettings.freeThresholds

        AppSettings.unlockPro()

        XCTAssertTrue(AppSettings.isProUnlocked)
        XCTAssertEqual(AppSettings.notificationThresholds, AppSettings.defaultThresholds)
    }

    func testLastNotificationAuthorizationStatusRoundTrip() {
        AppSettings.lastNotificationAuthorizationStatus = .denied
        XCTAssertEqual(AppSettings.lastNotificationAuthorizationStatus, .denied)

        AppSettings.lastNotificationAuthorizationStatus = .authorized
        XCTAssertEqual(AppSettings.lastNotificationAuthorizationStatus, .authorized)

        AppSettings.lastNotificationAuthorizationStatus = nil
        XCTAssertNil(AppSettings.lastNotificationAuthorizationStatus)
    }

    func testNormalizedProThresholdsFillMissingSlotsFromDefaults() {
        AppSettings.isProUnlocked = true
        AppSettings.notificationThresholds = [50, 7]

        XCTAssertEqual(AppSettings.notificationThresholds, [50, 7, 7, 1])
        XCTAssertEqual(AppSettings.uniqueThresholdsForScheduling(AppSettings.notificationThresholds), [50, 7, 1])
    }

    func testUnlockProPreservesCustomThresholds() {
        AppSettings.isProUnlocked = false
        AppSettings.notificationThresholds = [50, 51]

        AppSettings.unlockPro()

        XCTAssertEqual(AppSettings.notificationThresholds, [51, 50])
    }
}
