import AppKit

let application = NSApplication.shared
let delegate: NSApplicationDelegate
let arguments = CommandLine.arguments

if let sceneIndex = arguments.firstIndex(of: "--ab-scene") {
    let durationSeconds: TimeInterval
    if arguments.indices.contains(sceneIndex + 1),
       let parsedDuration = Double(arguments[sceneIndex + 1]),
       (30...3_600).contains(parsedDuration) {
        durationSeconds = parsedDuration
    } else {
        durationSeconds = 180
    }
    delegate = ABSceneAppDelegate(
        durationSeconds: durationSeconds,
        keepAliveEnabled: arguments.contains("--keep-alive")
    )
} else if arguments.contains("--diagnose") {
    let diagnosticIndex = arguments.firstIndex(of: "--diagnose")
    let requestedFramesPerSecond: Int
    if let diagnosticIndex,
       arguments.indices.contains(diagnosticIndex + 1),
       let parsedValue = Int(arguments[diagnosticIndex + 1]),
       (20...120).contains(parsedValue) {
        requestedFramesPerSecond = parsedValue
    } else {
        requestedFramesPerSecond = 120
    }
    let durationSeconds: TimeInterval
    if let diagnosticIndex,
       arguments.indices.contains(diagnosticIndex + 2),
       let parsedDuration = Double(arguments[diagnosticIndex + 2]),
       (4...60).contains(parsedDuration) {
        durationSeconds = parsedDuration
    } else {
        durationSeconds = 10
    }
    delegate = DiagnosticAppDelegate(
        requestedFramesPerSecond: requestedFramesPerSecond,
        durationSeconds: durationSeconds
    )
} else {
    delegate = AppDelegate()
}

application.delegate = delegate
application.run()
