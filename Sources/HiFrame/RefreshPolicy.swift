import Foundation

enum RefreshPolicy {
    static func evaluate(_ context: PolicyContext) -> PolicyDecision {
        guard context.isEnabled else {
            return .pause(.manuallyDisabled)
        }

        if context.power.source == .battery,
           let minimum = context.minimumBatteryPercent,
           let current = context.power.batteryPercent,
           current < minimum {
            return .pause(.batteryBelowThreshold(current: current, minimum: minimum))
        }

        switch context.policy {
        case .always:
            return .run
        case .powerAdapterOnly:
            return context.power.source == .adapter
                ? .run
                : .pause(.waitingForPowerAdapter)
        }
    }
}
