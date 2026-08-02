import AppKit

final class DiagnosticAppDelegate: NSObject, NSApplicationDelegate {
    private let engine = RefreshKeeperEngine()
    private let powerMonitor = PowerMonitor()
    private let requestedFramesPerSecond: Int
    private let durationSeconds: TimeInterval
    private var timer: Timer?

    init(requestedFramesPerSecond: Int, durationSeconds: TimeInterval) {
        self.requestedFramesPerSecond = requestedFramesPerSecond
        self.durationSeconds = durationSeconds
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        powerMonitor.refresh()
        engine.start(
            configuration: EngineConfiguration(
                requestedFramesPerSecond: requestedFramesPerSecond,
                displayTarget: .builtIn,
                signalPosition: .center
            )
        )

        timer = Timer.scheduledTimer(withTimeInterval: durationSeconds, repeats: false) { [weak self] _ in
            self?.finish()
        }
    }

    private func finish() {
        let telemetry = engine.currentTelemetry(forceSample: true)
        let displayCount = NSScreen.screens.count
        let builtInDisplayCount = NSScreen.screens.filter { screen in
            guard let displayID = screen.steadyFrameDisplayID else { return false }
            return CGDisplayIsBuiltin(displayID) != 0
        }.count
        let primarySurface = telemetry.primarySurface
        let presentationTiming = primarySurface?.presentationTiming
        let expectsDisplayLink: Bool
        if #available(macOS 14.0, *) {
            expectsDisplayLink = true
        } else {
            expectsDisplayLink = false
        }

        let surfaceResults: [[String: Any]] = telemetry.surfaces.map { surface in
            let timing = surface.presentationTiming
            return [
                "displayID": surface.displayID,
                "displayName": surface.displayName,
                "isBuiltIn": surface.isBuiltIn,
                "logicalWidthPoints": surface.logicalSizePoints.width,
                "logicalHeightPoints": surface.logicalSizePoints.height,
                "drawableWidthPixels": surface.drawableSizePixels.width,
                "drawableHeightPixels": surface.drawableSizePixels.height,
                "metalCompletedFPS": surface.measuredSubmissionFPS,
                "submittedFrames": surface.totalSubmittedFrames,
                "timingSource": surface.timingSource.rawValue,
                "estimatedPresentationFPS": timing?.estimatedFramesPerSecond ?? NSNull(),
                "targetPresentationIntervalMs": timing?.medianIntervalMilliseconds ?? NSNull(),
                "intervalP10Ms": timing?.p10IntervalMilliseconds ?? NSNull(),
                "intervalP90Ms": timing?.p90IntervalMilliseconds ?? NSNull(),
                "displayLinkJitterMs": timing?.jitterMilliseconds ?? NSNull(),
                "displayLinkSampleCount": timing?.sampleCount ?? 0
            ]
        }

        let result: [String: Any] = [
            "success": engine.isRunning
                && telemetry.totalSubmittedFrames > 0
                && (!expectsDisplayLink || presentationTiming != nil),
            "displayCount": displayCount,
            "builtInDisplayCount": builtInDisplayCount,
            "surfaceCount": telemetry.surfaceCount,
            "requestedFPS": requestedFramesPerSecond,
            "durationSeconds": durationSeconds,
            "metalCompletedFPS": telemetry.measuredSubmissionFPS,
            "submittedFrames": telemetry.totalSubmittedFrames,
            "timingSource": primarySurface?.timingSource.rawValue ?? "unavailable",
            "estimatedPresentationFPS": presentationTiming?.estimatedFramesPerSecond ?? NSNull(),
            "targetPresentationIntervalMs": presentationTiming?.medianIntervalMilliseconds ?? NSNull(),
            "intervalP10Ms": presentationTiming?.p10IntervalMilliseconds ?? NSNull(),
            "intervalP90Ms": presentationTiming?.p90IntervalMilliseconds ?? NSNull(),
            "displayLinkJitterMs": presentationTiming?.jitterMilliseconds ?? NSNull(),
            "displayLinkSampleCount": presentationTiming?.sampleCount ?? 0,
            "surfaceTelemetry": surfaceResults,
            "powerSource": powerMonitor.snapshot.source.title,
            "batteryPercent": powerMonitor.snapshot.batteryPercent as Any,
            "error": telemetry.lastError as Any,
            "disclaimer": "DisplayLink estimated presentation frequency and Metal completion frequency are not the physical panel refresh rate"
        ]

        if let data = try? JSONSerialization.data(
            withJSONObject: result,
            options: [.prettyPrinted, .sortedKeys]
        ), let output = String(data: data, encoding: .utf8) {
            print(output)
        }

        engine.stop()
        NSApp.terminate(nil)
    }
}
