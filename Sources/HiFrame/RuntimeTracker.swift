import Foundation

final class RuntimeTracker {
    private let settings: SettingsStore
    private var activeSince: Date?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var isActive: Bool { activeSince != nil }

    var currentSessionDuration: TimeInterval {
        guard let activeSince else { return 0 }
        return Date().timeIntervalSince(activeSince)
    }

    var totalDuration: TimeInterval {
        settings.totalActiveSeconds + currentSessionDuration
    }

    func start() {
        guard activeSince == nil else { return }
        activeSince = Date()
    }

    func stop() {
        guard let activeSince else { return }
        settings.totalActiveSeconds += Date().timeIntervalSince(activeSince)
        self.activeSince = nil
    }

    func checkpoint() {
        guard activeSince != nil else { return }
        stop()
        start()
    }
}
