import XCTest
@testable import SteadyFrame

final class RefreshPolicyTests: XCTestCase {
    func testDisabledAlwaysPauses() {
        let decision = RefreshPolicy.evaluate(
            context(enabled: false, policy: .always, power: .adapter)
        )

        XCTAssertEqual(decision, .pause(.manuallyDisabled))
    }

    func testPowerAdapterPolicyRunsOnAdapter() {
        let decision = RefreshPolicy.evaluate(
            context(enabled: true, policy: .powerAdapterOnly, power: .adapter)
        )

        XCTAssertEqual(decision, .run)
    }

    func testPowerAdapterPolicyPausesOnBattery() {
        let decision = RefreshPolicy.evaluate(
            context(enabled: true, policy: .powerAdapterOnly, power: .battery)
        )

        XCTAssertEqual(decision, .pause(.waitingForPowerAdapter))
    }

    func testBatteryThresholdOverridesAlwaysPolicy() {
        var testContext = context(enabled: true, policy: .always, power: .battery)
        testContext.minimumBatteryPercent = 20
        testContext.power.batteryPercent = 12

        let decision = RefreshPolicy.evaluate(testContext)

        XCTAssertEqual(
            decision,
            .pause(.batteryBelowThreshold(current: 12, minimum: 20))
        )
    }

    private func context(
        enabled: Bool,
        policy: ActivationPolicy,
        power: PowerSource
    ) -> PolicyContext {
        PolicyContext(
            isEnabled: enabled,
            policy: policy,
            minimumBatteryPercent: nil,
            power: PowerSnapshot(source: power, batteryPercent: 80, isCharging: false)
        )
    }
}
