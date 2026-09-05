import XCTest
@testable import HiFrame

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "HiFrameTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchDefaultsAreSafeAndUseful() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.isEnabled)
        XCTAssertEqual(store.requestedFramesPerSecond, 120)
        XCTAssertEqual(store.activationPolicy, .powerAdapterOnly)
        XCTAssertEqual(store.minimumBatteryPercent, 20)
        XCTAssertEqual(store.displayTarget, .builtIn)
        XCTAssertEqual(store.signalPosition, .center)
        XCTAssertEqual(store.appLanguage, .system)
    }

    func testSettingsRoundTrip() {
        let store = SettingsStore(defaults: defaults)
        store.requestedFramesPerSecond = 60
        store.activationPolicy = .always
        store.minimumBatteryPercent = nil
        store.displayTarget = .all
        store.signalPosition = .lowerRight
        store.appLanguage = .english
        store.totalActiveSeconds = 42

        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.requestedFramesPerSecond, 60)
        XCTAssertEqual(reloaded.activationPolicy, .always)
        XCTAssertNil(reloaded.minimumBatteryPercent)
        XCTAssertEqual(reloaded.displayTarget, .all)
        XCTAssertEqual(reloaded.signalPosition, .lowerRight)
        XCTAssertEqual(reloaded.appLanguage, .english)
        XCTAssertEqual(reloaded.totalActiveSeconds, 42)
    }

    func testInvalidLanguageFallsBackToSystem() {
        _ = SettingsStore(defaults: defaults)
        defaults.set("unsupported", forKey: "appLanguage")

        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.appLanguage, .system)
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), AppLanguage.system.rawValue)
    }

    func testRemovedNinetyFPSMigratesToOneHundredTwenty() {
        _ = SettingsStore(defaults: defaults)
        defaults.set(90, forKey: "requestedFPS")

        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.requestedFramesPerSecond, 120)
        XCTAssertEqual(defaults.integer(forKey: "requestedFPS"), 120)
    }

    func testRemovedSelectedApplicationPolicyFallsBackToPowerAdapter() {
        _ = SettingsStore(defaults: defaults)
        defaults.set("selectedApplications", forKey: "activationPolicy")
        defaults.set(["com.example.editor"], forKey: "allowedBundleIdentifiers")

        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.activationPolicy, .powerAdapterOnly)
        XCTAssertEqual(defaults.string(forKey: "activationPolicy"), "powerAdapterOnly")
        XCTAssertNil(defaults.object(forKey: "allowedBundleIdentifiers"))
    }

    func testRemovedSignalStrengthIsCleared() {
        defaults.set("strong", forKey: "signalStrength")

        _ = SettingsStore(defaults: defaults)

        XCTAssertNil(defaults.object(forKey: "signalStrength"))
    }
}
