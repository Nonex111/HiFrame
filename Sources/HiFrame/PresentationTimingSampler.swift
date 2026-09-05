import Foundation

/// Thread-safe rolling statistics for CAMetalDisplayLink target presentation times.
/// The median is used for the estimated frequency so occasional stalls do not
/// dominate the value shown to the user.
final class PresentationTimingSampler {
    private let lock = NSLock()
    private let maximumSampleCount: Int
    private var previousTimestamp: CFTimeInterval?
    private var intervals: [CFTimeInterval] = []

    init(maximumSampleCount: Int = 600) {
        self.maximumSampleCount = max(3, maximumSampleCount)
    }

    func record(targetPresentationTimestamp timestamp: CFTimeInterval) {
        guard timestamp.isFinite, timestamp > 0 else { return }

        lock.lock()
        defer { lock.unlock() }

        guard let previousTimestamp else {
            self.previousTimestamp = timestamp
            return
        }

        let interval = timestamp - previousTimestamp
        self.previousTimestamp = timestamp

        // A discontinuity generally means sleep, a display reconfiguration, or
        // a debugger pause. Start a new rolling window instead of averaging it in.
        guard interval >= 1.0 / 500.0, interval <= 0.25 else {
            intervals.removeAll(keepingCapacity: true)
            return
        }

        intervals.append(interval)
        if intervals.count > maximumSampleCount {
            intervals.removeFirst(intervals.count - maximumSampleCount)
        }
    }

    func snapshot() -> PresentationTimingSnapshot? {
        lock.lock()
        let values = intervals
        lock.unlock()

        guard values.count >= 3 else { return nil }
        let sorted = values.sorted()
        let median = percentile(0.5, sortedValues: sorted)
        guard median > 0 else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            let difference = value - mean
            return partial + difference * difference
        } / Double(values.count)

        return PresentationTimingSnapshot(
            estimatedFramesPerSecond: 1.0 / median,
            medianIntervalMilliseconds: median * 1_000,
            p10IntervalMilliseconds: percentile(0.1, sortedValues: sorted) * 1_000,
            p90IntervalMilliseconds: percentile(0.9, sortedValues: sorted) * 1_000,
            jitterMilliseconds: sqrt(variance) * 1_000,
            sampleCount: values.count
        )
    }

    func reset() {
        lock.lock()
        previousTimestamp = nil
        intervals.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    private func percentile(_ percentile: Double, sortedValues: [Double]) -> Double {
        let position = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }
        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex]
            + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
    }
}
