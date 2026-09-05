import Foundation
import ServiceManagement

final class LoginItemManager {
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    let isAppBundle: Bool

    init(
        isAppBundle: Bool = Bundle.main.bundleURL.pathExtension == "app",
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.isAppBundle = isAppBundle
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
    }

    // System Settings is authoritative; never persist a separate enabled flag.
    var status: SMAppService.Status { readStatus() }

    func setEnabled(_ enabled: Bool) throws {
        guard isAppBundle else { throw LoginItemError.appBundleRequired }
        let currentStatus = status
        if enabled {
            guard currentStatus != .enabled, currentStatus != .requiresApproval else { return }
            try register()
        } else {
            guard currentStatus != .notRegistered else { return }
            try unregister()
        }
    }

    private enum LoginItemError: LocalizedError {
        case appBundleRequired

        var errorDescription: String? {
            L10n.text(
                "login.appBundleRequired",
                fallback: "Open the packaged HiFrame.app to configure launch at login."
            )
        }
    }
}
