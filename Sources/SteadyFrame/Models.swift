import CoreGraphics
import Foundation

enum ActivationPolicy: String, CaseIterable {
    case always
    case powerAdapterOnly

    var title: String {
        switch self {
        case .always:
            return L10n.text("activation.always", fallback: "Always")
        case .powerAdapterOnly:
            return L10n.text("activation.powerOnly", fallback: "External power only")
        }
    }
}

enum DisplayTarget: String, CaseIterable {
    case builtIn
    case all

    var title: String {
        switch self {
        case .builtIn:
            return L10n.text("display.builtIn", fallback: "Built-in display only")
        case .all:
            return L10n.text("display.all", fallback: "All displays")
        }
    }
}

enum SignalPosition: String, CaseIterable {
    case lowerLeft
    case lowerRight
    case center

    var title: String {
        switch self {
        case .lowerLeft:
            return L10n.text("signal.lowerLeft", fallback: "Lower left")
        case .lowerRight:
            return L10n.text("signal.lowerRight", fallback: "Lower right")
        case .center:
            return L10n.text("signal.center", fallback: "Center")
        }
    }
}

enum SignalParameters {
    /// Fixed per-frame offset around middle gray. The alternating frames differ
    /// by 8/255 in the final 8-bit drawable.
    static let luminanceDelta = 4.0 / 255.0
    static let frameToFrameLuminanceDelta = luminanceDelta * 2
}

enum PowerSource: Equatable {
    case adapter
    case battery
    case unknown

    var title: String {
        switch self {
        case .adapter:
            return L10n.text("power.adapter", fallback: "Power adapter")
        case .battery:
            return L10n.text("power.battery", fallback: "Battery")
        case .unknown:
            return L10n.text("power.unknown", fallback: "Unknown power source")
        }
    }
}

struct PowerSnapshot: Equatable {
    var source: PowerSource
    var batteryPercent: Int?
    var isCharging: Bool

    static let unknown = PowerSnapshot(source: .unknown, batteryPercent: nil, isCharging: false)
}

struct PolicyContext {
    var isEnabled: Bool
    var policy: ActivationPolicy
    var minimumBatteryPercent: Int?
    var power: PowerSnapshot
}

enum PauseReason: Equatable {
    case manuallyDisabled
    case waitingForPowerAdapter
    case batteryBelowThreshold(current: Int, minimum: Int)

    var description: String {
        switch self {
        case .manuallyDisabled:
            return L10n.text("pause.manuallyDisabled", fallback: "Manually disabled")
        case .waitingForPowerAdapter:
            return L10n.text("pause.waitingForPower", fallback: "Waiting for external power")
        case let .batteryBelowThreshold(current, minimum):
            return L10n.format(
                "pause.batteryBelow",
                fallback: "Battery at %d%%, below %d%%",
                current,
                minimum
            )
        }
    }
}

struct PolicyDecision: Equatable {
    var shouldRun: Bool
    var pauseReason: PauseReason?

    static let run = PolicyDecision(shouldRun: true, pauseReason: nil)

    static func pause(_ reason: PauseReason) -> PolicyDecision {
        PolicyDecision(shouldRun: false, pauseReason: reason)
    }
}

struct EngineConfiguration: Equatable {
    var requestedFramesPerSecond: Int
    var displayTarget: DisplayTarget
    var signalPosition: SignalPosition
}

enum TimingSource: String {
    case caMetalDisplayLink
    case mtkViewTimer

    var title: String {
        switch self {
        case .caMetalDisplayLink: return "CAMetalDisplayLink"
        case .mtkViewTimer:
            return L10n.text("timing.mtkViewTimer", fallback: "MTKView timer")
        }
    }
}

struct PresentationTimingSnapshot: Equatable {
    var estimatedFramesPerSecond: Double
    var medianIntervalMilliseconds: Double
    var p10IntervalMilliseconds: Double
    var p90IntervalMilliseconds: Double
    var jitterMilliseconds: Double
    var sampleCount: Int
}

struct SurfaceTelemetry {
    var displayID: CGDirectDisplayID
    var displayName: String
    var isBuiltIn: Bool
    var logicalSizePoints: CGSize
    var drawableSizePixels: CGSize
    var measuredSubmissionFPS: Double
    var totalSubmittedFrames: UInt64
    var timingSource: TimingSource
    var presentationTiming: PresentationTimingSnapshot?
}

struct EngineTelemetry {
    var surfaceCount: Int = 0
    var measuredSubmissionFPS: Double = 0
    var totalSubmittedFrames: UInt64 = 0
    var surfaces: [SurfaceTelemetry] = []
    var lastError: String?

    var primarySurface: SurfaceTelemetry? {
        surfaces.first(where: \.isBuiltIn) ?? surfaces.first
    }
}
