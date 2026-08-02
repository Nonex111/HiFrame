import AppKit
import CoreGraphics

final class ABSceneAppDelegate: NSObject, NSApplicationDelegate {
    private let durationSeconds: TimeInterval
    private let keepAliveEnabled: Bool
    private let engine = RefreshKeeperEngine()
    private var windows: [NSWindow] = []
    private var timer: Timer?

    init(durationSeconds: TimeInterval, keepAliveEnabled: Bool) {
        self.durationSeconds = durationSeconds
        self.keepAliveEnabled = keepAliveEnabled
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        windows = NSScreen.screens.map(makeGrayWindow)
        windows.forEach { $0.orderFrontRegardless() }

        if keepAliveEnabled {
            engine.start(
                configuration: EngineConfiguration(
                    requestedFramesPerSecond: 120,
                    displayTarget: .builtIn,
                    signalPosition: .center
                )
            )
        }

        printEvent(name: "ready")
        timer = Timer.scheduledTimer(
            withTimeInterval: durationSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.finish()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        engine.stop()
        windows.forEach { $0.close() }
    }

    private func makeGrayWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(
            calibratedWhite: 0.18,
            alpha: 1
        ).cgColor
        window.contentView = view
        window.backgroundColor = NSColor(calibratedWhite: 0.18, alpha: 1)
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        window.isReleasedWhenClosed = false
        return window
    }

    private func finish() {
        printEvent(name: "complete")
        NSApp.terminate(nil)
    }

    private func printEvent(name: String) {
        let telemetry = engine.currentTelemetry(forceSample: true)
        let displays: [[String: Any]] = NSScreen.screens.map { screen in
            let displayID = screen.steadyFrameDisplayID ?? 0
            let mode = CGDisplayCopyDisplayMode(displayID)
            return [
                "displayID": displayID,
                "displayName": screen.localizedName,
                "isBuiltIn": CGDisplayIsBuiltin(displayID) != 0,
                "refreshRate": mode?.refreshRate ?? 0
            ]
        }
        let timing = telemetry.primarySurface?.presentationTiming
        let payload: [String: Any] = [
            "event": name,
            "durationSeconds": durationSeconds,
            "keepAliveEnabled": keepAliveEnabled,
            "pid": ProcessInfo.processInfo.processIdentifier,
            "displays": displays,
            "surfaceCount": telemetry.surfaceCount,
            "metalCompletedFPS": telemetry.measuredSubmissionFPS,
            "estimatedPresentationFPS": timing?.estimatedFramesPerSecond ?? NSNull(),
            "targetPresentationIntervalMs": timing?.medianIntervalMilliseconds ?? NSNull(),
            "displayLinkSampleCount": timing?.sampleCount ?? 0
        ]
        if let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let output = String(data: data, encoding: .utf8) {
            print(output)
            fflush(stdout)
        }
    }
}
