import AppKit
import CoreGraphics
import Metal
import MetalKit
import QuartzCore

extension NSScreen {
    var steadyFrameDisplayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value
    }
}

func signalSurfaceRect(in screenFrame: CGRect, position: SignalPosition) -> CGRect {
    let size = CGSize(width: 1, height: 1)
    let origin: CGPoint
    switch position {
    case .lowerLeft:
        origin = CGPoint(x: screenFrame.minX + 1, y: screenFrame.minY + 1)
    case .lowerRight:
        origin = CGPoint(
            x: screenFrame.maxX - size.width - 1,
            y: screenFrame.minY + 1
        )
    case .center:
        origin = CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
    }
    return CGRect(origin: origin, size: size)
}

private final class FrameCounter {
    private let lock = NSLock()
    private var frameCount: UInt64 = 0
    private var previousFrameCount: UInt64 = 0
    private var previousSampleDate = Date()
    private var latestFramesPerSecond: Double = 0

    func recordFrame() {
        lock.lock()
        frameCount &+= 1
        lock.unlock()
    }

    func sample() -> (fps: Double, total: UInt64) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        let interval = now.timeIntervalSince(previousSampleDate)
        if interval >= 0.25 {
            let newFrames = frameCount - previousFrameCount
            latestFramesPerSecond = Double(newFrames) / interval
            previousFrameCount = frameCount
            previousSampleDate = now
        }
        return (latestFramesPerSecond, frameCount)
    }
}

private final class PixelRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let frameCounter: FrameCounter
    private let presentationTimingSampler: PresentationTimingSampler
    private var frameIndex: UInt64 = 0

    init?(
        device: MTLDevice,
        frameCounter: FrameCounter,
        presentationTimingSampler: PresentationTimingSampler
    ) {
        guard let commandQueue = device.makeCommandQueue() else { return nil }
        self.commandQueue = commandQueue
        self.frameCounter = frameCounter
        self.presentationTimingSampler = presentationTimingSampler
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable else { return }
        render(drawable: drawable)
    }

    fileprivate func record(targetPresentationTimestamp: CFTimeInterval) {
        presentationTimingSampler.record(
            targetPresentationTimestamp: targetPresentationTimestamp
        )
    }

    fileprivate func render(drawable: any CAMetalDrawable) {
        autoreleasepool {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
            }

            frameIndex &+= 1
            let direction = frameIndex.isMultiple(of: 2) ? 1.0 : -1.0
            let gray = 0.5 + direction * SignalParameters.luminanceDelta
            let descriptor = MTLRenderPassDescriptor()
            let attachment = descriptor.colorAttachments[0]
            attachment?.texture = drawable.texture
            attachment?.loadAction = .clear
            attachment?.storeAction = .store
            attachment?.clearColor = MTLClearColor(
                red: gray,
                green: gray,
                blue: gray,
                alpha: 1
            )

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.addCompletedHandler { [frameCounter] _ in
                frameCounter.recordFrame()
            }
            commandBuffer.commit()
        }
    }
}

@available(macOS 14.0, *)
extension PixelRenderer: CAMetalDisplayLinkDelegate {
    func metalDisplayLink(
        _ link: CAMetalDisplayLink,
        needsUpdate update: CAMetalDisplayLink.Update
    ) {
        record(targetPresentationTimestamp: update.targetPresentationTimestamp)
        render(drawable: update.drawable)
    }
}

private protocol DisplayLinkControlling: AnyObject {
    func update(requestedFramesPerSecond: Int)
    func stop()
}

@available(macOS 14.0, *)
private final class MetalDisplayLinkController: DisplayLinkControlling {
    private let displayLink: CAMetalDisplayLink
    private var isStopped = false

    init(
        metalLayer: CAMetalLayer,
        renderer: PixelRenderer,
        requestedFramesPerSecond: Int
    ) {
        displayLink = CAMetalDisplayLink(metalLayer: metalLayer)
        displayLink.delegate = renderer
        displayLink.preferredFrameLatency = 1
        update(requestedFramesPerSecond: requestedFramesPerSecond)
        displayLink.add(to: .main, forMode: .common)
    }

    func update(requestedFramesPerSecond: Int) {
        let framesPerSecond = Float(requestedFramesPerSecond)
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: framesPerSecond,
            maximum: framesPerSecond,
            preferred: framesPerSecond
        )
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        displayLink.isPaused = true
        displayLink.delegate = nil
        displayLink.invalidate()
    }

    deinit {
        stop()
    }
}

private final class MetalPixelView: NSView {
    private let metalDevice: MTLDevice
    private let targetContentsScale: CGFloat

    var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }

    init(frame: CGRect, device: MTLDevice, contentsScale: CGFloat) {
        metalDevice = device
        targetContentsScale = contentsScale
        super.init(frame: frame)
        wantsLayer = true
        configureMetalLayer()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        CAMetalLayer()
    }

    override func layout() {
        super.layout()
        updateDrawableSize()
    }

    private func configureMetalLayer() {
        metalLayer.device = metalDevice
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.isOpaque = true
        metalLayer.contentsScale = targetContentsScale
        metalLayer.presentsWithTransaction = false
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        metalLayer.drawableSize = CGSize(
            width: max(1, bounds.width * targetContentsScale),
            height: max(1, bounds.height * targetContentsScale)
        )
    }
}

private final class KeepAliveSurface {
    let panel: NSPanel
    let contentView: NSView
    let renderer: PixelRenderer
    let frameCounter: FrameCounter
    let presentationTimingSampler: PresentationTimingSampler
    let displayID: CGDirectDisplayID
    let displayName: String
    let isBuiltIn: Bool
    private(set) var timingSource: TimingSource = .mtkViewTimer
    private let fallbackMTKView: MTKView?
    private var displayLinkController: DisplayLinkControlling?

    init?(
        screen: NSScreen,
        requestedFramesPerSecond: Int,
        signalPosition: SignalPosition,
        device: MTLDevice
    ) {
        guard let displayID = screen.steadyFrameDisplayID else {
            return nil
        }

        self.displayID = displayID
        displayName = screen.localizedName
        isBuiltIn = CGDisplayIsBuiltin(displayID) != 0
        frameCounter = FrameCounter()
        presentationTimingSampler = PresentationTimingSampler()
        guard let renderer = PixelRenderer(
            device: device,
            frameCounter: frameCounter,
            presentationTimingSampler: presentationTimingSampler
        ) else {
            return nil
        }
        self.renderer = renderer

        let rect = signalSurfaceRect(in: screen.frame, position: signalPosition)
        let createdPanel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        createdPanel.isOpaque = true
        createdPanel.backgroundColor = .black
        createdPanel.hasShadow = false
        createdPanel.ignoresMouseEvents = true
        createdPanel.hidesOnDeactivate = false
        createdPanel.level = .screenSaver
        createdPanel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        createdPanel.isReleasedWhenClosed = false

        let createdContentView: NSView
        let createdFallbackMTKView: MTKView?
        let createdTimingSource: TimingSource
        let createdDisplayLinkController: DisplayLinkControlling?

        if #available(macOS 14.0, *) {
            let metalView = MetalPixelView(
                frame: CGRect(origin: .zero, size: rect.size),
                device: device,
                contentsScale: screen.backingScaleFactor
            )
            createdContentView = metalView
            createdFallbackMTKView = nil
            createdTimingSource = .caMetalDisplayLink
            createdPanel.contentView = metalView
            createdPanel.orderFrontRegardless()
            createdDisplayLinkController = MetalDisplayLinkController(
                metalLayer: metalView.metalLayer,
                renderer: renderer,
                requestedFramesPerSecond: requestedFramesPerSecond
            )
        } else {
            let metalKitView = MTKView(
                frame: CGRect(origin: .zero, size: rect.size),
                device: device
            )
            metalKitView.colorPixelFormat = .bgra8Unorm
            metalKitView.framebufferOnly = true
            metalKitView.preferredFramesPerSecond = requestedFramesPerSecond
            metalKitView.enableSetNeedsDisplay = false
            metalKitView.isPaused = false
            metalKitView.clearColor = MTLClearColor(
                red: 0.5,
                green: 0.5,
                blue: 0.5,
                alpha: 1
            )
            metalKitView.delegate = renderer
            createdContentView = metalKitView
            createdFallbackMTKView = metalKitView
            createdTimingSource = .mtkViewTimer
            createdDisplayLinkController = nil
            createdPanel.contentView = metalKitView
            createdPanel.orderFrontRegardless()
        }

        panel = createdPanel
        contentView = createdContentView
        fallbackMTKView = createdFallbackMTKView
        timingSource = createdTimingSource
        displayLinkController = createdDisplayLinkController
    }

    func update(requestedFramesPerSecond: Int) {
        fallbackMTKView?.preferredFramesPerSecond = requestedFramesPerSecond
        displayLinkController?.update(requestedFramesPerSecond: requestedFramesPerSecond)
        panel.orderFrontRegardless()
    }

    func sampleTelemetry() -> SurfaceTelemetry {
        let frameSample = frameCounter.sample()
        let drawableSize: CGSize
        if let metalView = contentView as? MetalPixelView {
            drawableSize = metalView.metalLayer.drawableSize
        } else if let fallbackMTKView {
            drawableSize = fallbackMTKView.drawableSize
        } else {
            drawableSize = .zero
        }
        return SurfaceTelemetry(
            displayID: displayID,
            displayName: displayName,
            isBuiltIn: isBuiltIn,
            logicalSizePoints: contentView.bounds.size,
            drawableSizePixels: drawableSize,
            measuredSubmissionFPS: frameSample.fps,
            totalSubmittedFrames: frameSample.total,
            timingSource: timingSource,
            presentationTiming: presentationTimingSampler.snapshot()
        )
    }

    func stop() {
        displayLinkController?.stop()
        displayLinkController = nil
        fallbackMTKView?.isPaused = true
        presentationTimingSampler.reset()
        panel.orderOut(nil)
        panel.close()
    }
}

final class RefreshKeeperEngine {
    private(set) var isRunning = false
    private(set) var configuration: EngineConfiguration?
    private var surfaces: [KeepAliveSurface] = []
    private var telemetry = EngineTelemetry()
    private var lastSampleDate = Date.distantPast

    var onDisplayConfigurationChanged: (() -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start(configuration: EngineConfiguration) {
        if isRunning, self.configuration == configuration {
            surfaces.forEach {
                $0.update(requestedFramesPerSecond: configuration.requestedFramesPerSecond)
            }
            return
        }

        stop()
        self.configuration = configuration

        guard let device = MTLCreateSystemDefaultDevice() else {
            telemetry.lastError = L10n.text(
                "error.noMetal",
                fallback: "No Metal device is available on this Mac"
            )
            return
        }

        let targetScreens = screens(for: configuration.displayTarget)
        guard !targetScreens.isEmpty else {
            telemetry.lastError = configuration.displayTarget == .builtIn
                ? L10n.text(
                    "error.noBuiltInDisplay",
                    fallback: "No built-in display was detected"
                )
                : L10n.text(
                    "error.noDisplay",
                    fallback: "No available display was detected"
                )
            return
        }

        surfaces = targetScreens.compactMap { screen in
            KeepAliveSurface(
                screen: screen,
                requestedFramesPerSecond: configuration.requestedFramesPerSecond,
                signalPosition: configuration.signalPosition,
                device: device
            )
        }

        guard !surfaces.isEmpty else {
            telemetry.lastError = L10n.text(
                "error.surfaceCreation",
                fallback: "Unable to create the Metal refresh-rate keeper surface"
            )
            return
        }

        telemetry = EngineTelemetry(surfaceCount: surfaces.count)
        lastSampleDate = .distantPast
        isRunning = true
    }

    func stop() {
        surfaces.forEach { $0.stop() }
        surfaces.removeAll()
        isRunning = false
        configuration = nil
        telemetry.surfaceCount = 0
        telemetry.measuredSubmissionFPS = 0
        telemetry.surfaces = []
    }

    func currentTelemetry(forceSample: Bool = false) -> EngineTelemetry {
        let now = Date()
        guard forceSample || now.timeIntervalSince(lastSampleDate) >= 0.75 else {
            return telemetry
        }
        lastSampleDate = now

        let samples = surfaces.map { $0.sampleTelemetry() }
        telemetry.surfaceCount = samples.count
        telemetry.measuredSubmissionFPS = samples.isEmpty
            ? 0
            : samples.map(\.measuredSubmissionFPS).reduce(0, +) / Double(samples.count)
        telemetry.totalSubmittedFrames = samples.map(\.totalSubmittedFrames).reduce(0, +)
        telemetry.surfaces = samples
        return telemetry
    }

    private func screens(for target: DisplayTarget) -> [NSScreen] {
        switch target {
        case .all:
            return NSScreen.screens
        case .builtIn:
            return NSScreen.screens.filter { screen in
                guard let displayID = screen.steadyFrameDisplayID else {
                    return false
                }
                return CGDisplayIsBuiltin(displayID) != 0
            }
        }
    }

    @objc private func screenParametersChanged() {
        guard isRunning, let configuration else {
            onDisplayConfigurationChanged?()
            return
        }
        stop()
        start(configuration: configuration)
        onDisplayConfigurationChanged?()
    }
}
