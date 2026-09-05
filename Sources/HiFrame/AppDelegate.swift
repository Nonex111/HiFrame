import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsStore()
    private let powerMonitor = PowerMonitor()
    private let engine = RefreshKeeperEngine()
    private let loginItemManager = LoginItemManager()
    private let updateChecker = UpdateChecker()
    private var releaseCheckTask: Task<Void, Never>?
    private weak var checkUpdatesMenuItem: NSMenuItem?
    private lazy var runtimeTracker = RuntimeTracker(settings: settings)

    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private lazy var menuBarIcon: NSImage? = {
        guard let icon = NSApp.applicationIconImage.copy() as? NSImage else {
            return nil
        }
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        return icon
    }()
    private var updateTimer: Timer?
    private var hotKeyManager: HotKeyManager?
    private weak var liveFPSMenuItem: NSMenuItem?
    private var decision: PolicyDecision = .pause(.manuallyDisabled)
    private var timerTicks = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        L10n.language = settings.appLanguage
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        powerMonitor.onChange = { [weak self] _ in
            self?.evaluatePolicy()
        }
        powerMonitor.start()

        engine.onDisplayConfigurationChanged = { [weak self] in
            self?.evaluatePolicy()
        }

        hotKeyManager = HotKeyManager { [weak self] in
            self?.toggleEnabled()
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
        if let updateTimer {
            RunLoop.main.add(updateTimer, forMode: .common)
        }

        evaluatePolicy()
        performUpdateCheck(manual: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        releaseCheckTask?.cancel()
        runtimeTracker.stop()
        powerMonitor.stop()
        updateTimer?.invalidate()
        engine.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    func menuDidClose(_ menu: NSMenu) {
        liveFPSMenuItem = nil
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu = NSMenu()
        statusMenu.delegate = self
        let startingItem = NSMenuItem(
            title: L10n.text("menu.starting", fallback: "HiFrame is starting…"),
            action: nil,
            keyEquivalent: ""
        )
        startingItem.isEnabled = false
        statusMenu.addItem(startingItem)
        statusItem.menu = statusMenu
        updateStatusButton()
    }

    private func evaluatePolicy() {
        decision = RefreshPolicy.evaluate(
            PolicyContext(
                isEnabled: settings.isEnabled,
                policy: settings.activationPolicy,
                minimumBatteryPercent: settings.minimumBatteryPercent,
                power: powerMonitor.snapshot
            )
        )

        if decision.shouldRun {
            engine.start(configuration: settings.engineConfiguration)
            if engine.isRunning {
                runtimeTracker.start()
            } else {
                runtimeTracker.stop()
            }
        } else {
            engine.stop()
            runtimeTracker.stop()
        }

        updateStatusButton()
    }

    private func timerFired() {
        timerTicks += 1
        if timerTicks.isMultiple(of: 3_600) {
            performUpdateCheck(manual: false)
        }
        let telemetry = engine.currentTelemetry()
        if timerTicks.isMultiple(of: 30) {
            runtimeTracker.checkpoint()
            powerMonitor.refresh()
        }
        updateLiveFPSMenuItem(telemetry: telemetry)
        updateStatusButton()
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        let active = engine.isRunning
        button.image = menuBarIcon
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.alphaValue = active ? 1 : 0.45
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = active
            ? L10n.text("status.running", fallback: "HiFrame is running")
            : L10n.format(
                "status.tooltipPaused",
                fallback: "HiFrame: %@",
                decision.pauseReason?.description
                    ?? L10n.text("status.notRunning", fallback: "Not running")
            )
        button.setAccessibilityValue(
            active
                ? L10n.text("accessibility.running", fallback: "Running")
                : L10n.text("accessibility.paused", fallback: "Paused")
        )
        button.setAccessibilityLabel("HiFrame")
    }

    private func rebuildMenu() {
        statusMenu.removeAllItems()
        let telemetry = engine.currentTelemetry(forceSample: true)
        liveFPSMenuItem = addDisabledItem(
            liveFPSMenuTitle(telemetry: telemetry),
            emphasized: true
        )

        statusMenu.addItem(.separator())
        let enabledItem = actionItem(
            title: L10n.text("menu.enableKeeper", fallback: "Enable refresh-rate keeper"),
            action: #selector(toggleEnabled),
            state: settings.isEnabled ? .on : .off
        )
        enabledItem.keyEquivalent = "h"
        enabledItem.keyEquivalentModifierMask = [.command, .option, .control]
        statusMenu.addItem(enabledItem)

        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.requestedFrameRate", fallback: "Requested frame rate"),
            items: [60, 120].map { fps in
            actionItem(
                title: "\(fps) fps",
                action: #selector(changeRequestedFPS(_:)),
                representedObject: fps,
                state: settings.requestedFramesPerSecond == fps ? .on : .off
            )
            }
        ))

        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.activationPolicy", fallback: "Activation policy"),
            items: ActivationPolicy.allCases.map { policy in
            actionItem(
                title: policy.title,
                action: #selector(changeActivationPolicy(_:)),
                representedObject: policy.rawValue,
                state: settings.activationPolicy == policy ? .on : .off
            )
            }
        ))

        let thresholdValues: [Int?] = [nil, 10, 20, 30, 40]
        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.batteryProtection", fallback: "Low-battery protection"),
            items: thresholdValues.map { threshold in
            actionItem(
                title: threshold.map {
                    L10n.format("menu.stopBelow", fallback: "Stop below %d%%", $0)
                } ?? L10n.text("menu.off", fallback: "Off"),
                action: #selector(changeBatteryThreshold(_:)),
                representedObject: threshold ?? 0,
                state: settings.minimumBatteryPercent == threshold ? .on : .off
            )
            }
        ))

        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.signalPosition", fallback: "Signal position"),
            items: SignalPosition.allCases.map { position in
            actionItem(
                title: position.title,
                action: #selector(changeSignalPosition(_:)),
                representedObject: position.rawValue,
                state: settings.signalPosition == position ? .on : .off
            )
            }
        ))

        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.targetDisplay", fallback: "Target display"),
            items: DisplayTarget.allCases.map { target in
            actionItem(
                title: target.title,
                action: #selector(changeDisplayTarget(_:)),
                representedObject: target.rawValue,
                state: settings.displayTarget == target ? .on : .off
            )
            }
        ))

        statusMenu.addItem(submenuItem(
            title: L10n.text("menu.language", fallback: "Language"),
            items: AppLanguage.allCases.map { language in
            actionItem(
                title: language.title,
                action: #selector(changeLanguage(_:)),
                representedObject: language.rawValue,
                state: settings.appLanguage == language ? .on : .off
            )
            }
        ))

        let loginStatus = loginItemManager.status
        statusMenu.addItem(actionItem(
            title: L10n.text("menu.launchAtLogin", fallback: "Launch at Login"),
            action: #selector(toggleLaunchAtLogin),
            state: loginStatus == .enabled ? .on : loginStatus == .requiresApproval ? .mixed : .off,
            enabled: loginItemManager.isAppBundle
        ))
        if loginStatus == .requiresApproval {
            statusMenu.addItem(actionItem(
                title: L10n.text("login.approvalRequired", fallback: "Approve in System Settings…"),
                action: #selector(openLoginItemSettings)
            ))
        }

        statusMenu.addItem(.separator())
        let checkItem = actionItem(
            title: updateChecker.isChecking
                ? L10n.text("update.checking", fallback: "Checking for Updates…")
                : L10n.text("menu.checkUpdates", fallback: "Check for Updates…"),
            action: #selector(checkForUpdates),
            enabled: !updateChecker.isChecking
        )
        statusMenu.addItem(checkItem)
        checkUpdatesMenuItem = checkItem
        statusMenu.addItem(actionItem(
            title: L10n.text("menu.copyDiagnostics", fallback: "Copy diagnostics"),
            action: #selector(copyDiagnostics)
        ))
        statusMenu.addItem(actionItem(
            title: L10n.text("menu.about", fallback: "About HiFrame…"),
            action: #selector(showAbout)
        ))
        statusMenu.addItem(.separator())
        statusMenu.addItem(actionItem(
            title: L10n.text("menu.quit", fallback: "Quit HiFrame"),
            action: #selector(quit)
        ))
    }

    private func submenuItem(title: String, items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)
        items.forEach(submenu.addItem)
        parent.submenu = submenu
        return parent
    }

    private func actionItem(
        title: String,
        action: Selector,
        representedObject: Any? = nil,
        state: NSControl.StateValue = .off,
        enabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = representedObject
        item.state = state
        item.isEnabled = enabled
        return item
    }

    @discardableResult
    private func addDisabledItem(_ title: String, emphasized: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if emphasized {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
            )
        }
        statusMenu.addItem(item)
        return item
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func updateLiveFPSMenuItem(telemetry: EngineTelemetry) {
        guard let item = liveFPSMenuItem else { return }
        let title = liveFPSMenuTitle(telemetry: telemetry)
        item.title = title
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        )
    }

    private func liveFPSMenuTitle(telemetry: EngineTelemetry) -> String {
        if engine.isRunning {
            guard telemetry.measuredSubmissionFPS >= 1 else {
                return L10n.text("live.collecting", fallback: "Live rendering: collecting…")
            }
            return L10n.format(
                "live.fps",
                fallback: "Live rendering: %.1f fps",
                telemetry.measuredSubmissionFPS
            )
        }
        if let error = telemetry.lastError, decision.shouldRun {
            return L10n.format(
                "live.unavailable",
                fallback: "Live rendering: unavailable (%@)",
                error
            )
        }
        return L10n.text("live.paused", fallback: "Live rendering: paused")
    }

    @objc private func toggleEnabled() {
        settings.isEnabled.toggle()
        evaluatePolicy()
    }

    @objc private func changeRequestedFPS(_ sender: NSMenuItem) {
        guard let fps = sender.representedObject as? Int else { return }
        settings.requestedFramesPerSecond = fps
        evaluatePolicy()
    }

    @objc private func changeActivationPolicy(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let policy = ActivationPolicy(rawValue: value) else { return }
        settings.activationPolicy = policy
        evaluatePolicy()
    }

    @objc private func changeBatteryThreshold(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Int else { return }
        settings.minimumBatteryPercent = value > 0 ? value : nil
        evaluatePolicy()
    }

    @objc private func changeSignalPosition(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let position = SignalPosition(rawValue: value) else { return }
        settings.signalPosition = position
        evaluatePolicy()
    }

    @objc private func changeDisplayTarget(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let target = DisplayTarget(rawValue: value) else { return }
        settings.displayTarget = target
        evaluatePolicy()
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String,
              let language = AppLanguage(rawValue: value) else { return }
        settings.appLanguage = language
        L10n.language = language
        updateStatusButton()
        rebuildMenu()
    }

    @objc private func checkForUpdates() {
        performUpdateCheck(manual: true)
    }

    private func performUpdateCheck(manual: Bool) {
        guard releaseCheckTask == nil else { return }
        releaseCheckTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.releaseCheckTask = nil
                self.checkUpdatesMenuItem?.title = L10n.text("menu.checkUpdates", fallback: "Check for Updates…")
                self.checkUpdatesMenuItem?.isEnabled = true
            }
            self.checkUpdatesMenuItem?.title = L10n.text("update.checking", fallback: "Checking for Updates…")
            self.checkUpdatesMenuItem?.isEnabled = false
            do {
                let outcome = try await self.updateChecker.check(manual: manual)
                guard !Task.isCancelled, let outcome else { return }
                switch outcome {
                case .available(let release):
                    self.showUpdateAlert(
                        title: L10n.text("update.available", fallback: "A new HiFrame version is available"),
                        message: L10n.format("update.versions", fallback: "Current version: %@\nNew version: %@", self.updateChecker.currentVersion, release.tagName),
                        pageURL: release.pageURL
                    )
                case .upToDate:
                    if manual {
                        self.showUpdateAlert(
                            title: L10n.text("update.upToDate", fallback: "You’re up to date"),
                            message: L10n.format("update.currentVersion", fallback: "HiFrame %@", self.updateChecker.currentVersion)
                        )
                    }
                }
            } catch {
                guard manual, !Task.isCancelled else { return }
                self.showUpdateAlert(
                    title: L10n.text("update.failed", fallback: "Could not check for updates"),
                    message: error.localizedDescription,
                    pageURL: UpdateChecker.releasesURL
                )
            }
        }
    }

    private func showUpdateAlert(title: String, message: String, pageURL: URL? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        if pageURL != nil {
            alert.addButton(withTitle: L10n.text("update.openRelease", fallback: "Open Releases Page"))
            alert.addButton(withTitle: L10n.text("update.later", fallback: "Later"))
        } else {
            alert.addButton(withTitle: L10n.text("common.ok", fallback: "OK"))
        }
        if alert.runModal() == .alertFirstButtonReturn, let pageURL {
            NSWorkspace.shared.open(pageURL)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let currentStatus = loginItemManager.status
        let enable = currentStatus != .enabled && currentStatus != .requiresApproval
        do {
            try loginItemManager.setEnabled(enable)
            if enable, loginItemManager.status == .requiresApproval {
                openLoginItemSettings()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.text(
                "login.changeFailed", fallback: "Could not change launch at login"
            )
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: L10n.text("common.ok", fallback: "OK"))
            alert.addButton(withTitle: L10n.text(
                "login.openSettings", fallback: "Open Login Items Settings…"
            ))
            if alert.runModal() == .alertSecondButtonReturn {
                openLoginItemSettings()
            }
        }
        rebuildMenu()
    }

    @objc private func openLoginItemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @objc private func copyDiagnostics() {
        let telemetry = engine.currentTelemetry(forceSample: true)
        let screenDescriptions = NSScreen.screens.map { screen -> String in
            let displayID = screen.steadyFrameDisplayID
            let builtIn = displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
            return "\(screen.localizedName) \(Int(screen.frame.width))x\(Int(screen.frame.height)) builtIn=\(builtIn)"
        }
        let report = [
            "HiFrame diagnostics",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "enabled: \(settings.isEnabled)",
            "language: \(settings.appLanguage.rawValue)",
            "launchAtLoginStatus: \(loginItemManager.status.rawValue)",
            "policy: \(settings.activationPolicy.rawValue)",
            "decision: \(decision.shouldRun ? "run" : decision.pauseReason?.description ?? "pause")",
            "requestedFPS: \(settings.requestedFramesPerSecond)",
            String(format: "measuredSubmissionFPS: %.1f", telemetry.measuredSubmissionFPS),
            presentationDiagnostics(for: telemetry),
            "surfaces: \(telemetry.surfaceCount)",
            "target: \(settings.displayTarget.rawValue)",
            "signalPosition: \(settings.signalPosition.rawValue)",
            "power: \(powerMonitor.snapshot.source.title) \(powerMonitor.snapshot.batteryPercent.map(String.init) ?? "unknown")%",
            "currentSessionDuration: \(formatDuration(runtimeTracker.currentSessionDuration))",
            "totalRuntime: \(formatDuration(runtimeTracker.totalDuration))",
            "screens: \(screenDescriptions.joined(separator: "; "))",
            "note: submitted fps is not a measurement of the panel refresh rate"
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private func presentationDiagnostics(for telemetry: EngineTelemetry) -> String {
        guard !telemetry.surfaces.isEmpty else {
            return "displayTimings: unavailable"
        }

        let descriptions = telemetry.surfaces.map { surface -> String in
            guard let timing = surface.presentationTiming else {
                return "\(surface.displayName) source=\(surface.timingSource.rawValue) estimate=unavailable"
            }
            return String(
                format: "%@ logical=%.0fx%.0fpt drawable=%.0fx%.0fpx source=%@ estimatedPresentationFPS=%.2f intervalMs=%.3f p10Ms=%.3f p90Ms=%.3f jitterMs=%.3f samples=%d",
                surface.displayName,
                surface.logicalSizePoints.width,
                surface.logicalSizePoints.height,
                surface.drawableSizePixels.width,
                surface.drawableSizePixels.height,
                surface.timingSource.rawValue,
                timing.estimatedFramesPerSecond,
                timing.medianIntervalMilliseconds,
                timing.p10IntervalMilliseconds,
                timing.p90IntervalMilliseconds,
                timing.jitterMilliseconds,
                timing.sampleCount
            )
        }
        return "displayTimings: \(descriptions.joined(separator: "; "))"
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "HiFrame"
        alert.informativeText = L10n.text(
            "about.description",
            fallback: "A ProMotion refresh-rate keeper that requests active rendering through tiny, continuous pixel changes. It aims to reduce visible flicker and discomfort in static dark-gray scenes."
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text("common.ok", fallback: "OK"))
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
