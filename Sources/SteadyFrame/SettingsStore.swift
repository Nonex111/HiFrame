import Foundation

final class SettingsStore {
    private enum Key {
        static let enabled = "enabled"
        static let requestedFPS = "requestedFPS"
        static let activationPolicy = "activationPolicy"
        static let minimumBatteryPercent = "minimumBatteryPercent"
        static let displayTarget = "displayTarget"
        static let legacySignalStrength = "signalStrength"
        static let signalPosition = "signalPosition"
        static let legacyAllowedBundleIdentifiers = "allowedBundleIdentifiers"
        static let totalActiveSeconds = "totalActiveSeconds"
        static let defaultsRegistered = "defaultsRegistered"
    }

    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.enabled) }
    }

    var requestedFramesPerSecond: Int {
        didSet { defaults.set(requestedFramesPerSecond, forKey: Key.requestedFPS) }
    }

    var activationPolicy: ActivationPolicy {
        didSet { defaults.set(activationPolicy.rawValue, forKey: Key.activationPolicy) }
    }

    var minimumBatteryPercent: Int? {
        didSet { defaults.set(minimumBatteryPercent ?? 0, forKey: Key.minimumBatteryPercent) }
    }

    var displayTarget: DisplayTarget {
        didSet { defaults.set(displayTarget.rawValue, forKey: Key.displayTarget) }
    }

    var signalPosition: SignalPosition {
        didSet { defaults.set(signalPosition.rawValue, forKey: Key.signalPosition) }
    }

    var totalActiveSeconds: TimeInterval {
        didSet { defaults.set(totalActiveSeconds, forKey: Key.totalActiveSeconds) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if !defaults.bool(forKey: Key.defaultsRegistered) {
            defaults.set(true, forKey: Key.enabled)
            defaults.set(120, forKey: Key.requestedFPS)
            defaults.set(ActivationPolicy.powerAdapterOnly.rawValue, forKey: Key.activationPolicy)
            defaults.set(20, forKey: Key.minimumBatteryPercent)
            defaults.set(DisplayTarget.builtIn.rawValue, forKey: Key.displayTarget)
            defaults.set(SignalPosition.center.rawValue, forKey: Key.signalPosition)
            defaults.set(true, forKey: Key.defaultsRegistered)
        }

        isEnabled = defaults.bool(forKey: Key.enabled)
        let storedFPS = defaults.integer(forKey: Key.requestedFPS)
        requestedFramesPerSecond = storedFPS == 60 ? 60 : 120
        if storedFPS != requestedFramesPerSecond {
            defaults.set(requestedFramesPerSecond, forKey: Key.requestedFPS)
        }
        let storedActivationPolicy = defaults.string(forKey: Key.activationPolicy) ?? ""
        activationPolicy = ActivationPolicy(rawValue: storedActivationPolicy) ?? .powerAdapterOnly
        if ActivationPolicy(rawValue: storedActivationPolicy) == nil {
            defaults.set(activationPolicy.rawValue, forKey: Key.activationPolicy)
        }
        defaults.removeObject(forKey: Key.legacyAllowedBundleIdentifiers)
        defaults.removeObject(forKey: Key.legacySignalStrength)
        let threshold = defaults.integer(forKey: Key.minimumBatteryPercent)
        minimumBatteryPercent = threshold > 0 ? threshold : nil
        displayTarget = DisplayTarget(
            rawValue: defaults.string(forKey: Key.displayTarget) ?? ""
        ) ?? .builtIn
        let storedSignalPosition = defaults.string(forKey: Key.signalPosition) ?? ""
        signalPosition = SignalPosition(rawValue: storedSignalPosition) ?? .center
        if SignalPosition(rawValue: storedSignalPosition) == nil {
            defaults.set(signalPosition.rawValue, forKey: Key.signalPosition)
        }
        totalActiveSeconds = defaults.double(forKey: Key.totalActiveSeconds)
    }

    var engineConfiguration: EngineConfiguration {
        EngineConfiguration(
            requestedFramesPerSecond: requestedFramesPerSecond,
            displayTarget: displayTarget,
            signalPosition: signalPosition
        )
    }
}
