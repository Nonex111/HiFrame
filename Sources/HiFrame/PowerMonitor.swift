import Foundation
import IOKit.ps

final class PowerMonitor {
    private(set) var snapshot: PowerSnapshot = .unknown
    private(set) var observedDischargePercentPerHour: Double?
    var onChange: ((PowerSnapshot) -> Void)?

    private var timer: Timer?
    private var samples: [(date: Date, percent: Int)] = []

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let newSnapshot = readSnapshot()
        updateDischargeObservation(with: newSnapshot)
        let changed = newSnapshot != snapshot
        snapshot = newSnapshot
        if changed {
            onChange?(newSnapshot)
        }
    }

    private func readSnapshot() -> PowerSnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sourceList = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unknown
        }

        for source in sourceList {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else {
                continue
            }

            let sourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let powerSource: PowerSource
            if sourceState == kIOPSACPowerValue {
                powerSource = .adapter
            } else if sourceState == kIOPSBatteryPowerValue {
                powerSource = .battery
            } else {
                powerSource = .unknown
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let maximum = description[kIOPSMaxCapacityKey as String] as? Int
            let percent: Int?
            if let current, let maximum, maximum > 0 {
                percent = Int((Double(current) / Double(maximum) * 100).rounded())
            } else {
                percent = current
            }

            return PowerSnapshot(
                source: powerSource,
                batteryPercent: percent,
                isCharging: description[kIOPSIsChargingKey as String] as? Bool ?? false
            )
        }

        return .unknown
    }

    private func updateDischargeObservation(with snapshot: PowerSnapshot) {
        guard snapshot.source == .battery,
              !snapshot.isCharging,
              let percent = snapshot.batteryPercent else {
            samples.removeAll()
            observedDischargePercentPerHour = nil
            return
        }

        let now = Date()
        samples.append((now, percent))
        samples.removeAll { now.timeIntervalSince($0.date) > 30 * 60 }

        guard let first = samples.first,
              now.timeIntervalSince(first.date) >= 5 * 60 else {
            observedDischargePercentPerHour = nil
            return
        }

        let hours = now.timeIntervalSince(first.date) / 3600
        let drop = Double(first.percent - percent)
        observedDischargePercentPerHour = drop > 0 ? drop / hours : nil
    }
}
