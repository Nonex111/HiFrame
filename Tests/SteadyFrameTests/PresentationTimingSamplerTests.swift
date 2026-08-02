import XCTest
@testable import SteadyFrame

final class PresentationTimingSamplerTests: XCTestCase {
    func testRegular120FPSTimestampsProduceExpectedEstimate() throws {
        let sampler = PresentationTimingSampler(maximumSampleCount: 600)
        recordRegularSamples(count: 121, fps: 120, into: sampler)

        let snapshot = try XCTUnwrap(sampler.snapshot())

        XCTAssertEqual(snapshot.estimatedFramesPerSecond, 120, accuracy: 0.01)
        XCTAssertEqual(snapshot.medianIntervalMilliseconds, 8.333, accuracy: 0.001)
        XCTAssertEqual(snapshot.p10IntervalMilliseconds, 8.333, accuracy: 0.001)
        XCTAssertEqual(snapshot.p90IntervalMilliseconds, 8.333, accuracy: 0.001)
        XCTAssertEqual(snapshot.jitterMilliseconds, 0, accuracy: 0.001)
        XCTAssertEqual(snapshot.sampleCount, 120)
    }

    func testMedianEstimateResistsAnOccasionalLongFrame() throws {
        let sampler = PresentationTimingSampler(maximumSampleCount: 600)
        var timestamp = 10.0
        sampler.record(targetPresentationTimestamp: timestamp)
        for index in 0..<120 {
            timestamp += index == 60 ? 1.0 / 30.0 : 1.0 / 120.0
            sampler.record(targetPresentationTimestamp: timestamp)
        }

        let snapshot = try XCTUnwrap(sampler.snapshot())

        XCTAssertEqual(snapshot.estimatedFramesPerSecond, 120, accuracy: 0.01)
        XCTAssertGreaterThan(snapshot.jitterMilliseconds, 0)
        XCTAssertEqual(snapshot.p90IntervalMilliseconds, 8.333, accuracy: 0.001)
    }

    func testDiscontinuityStartsANewSampleWindow() throws {
        let sampler = PresentationTimingSampler(maximumSampleCount: 600)
        recordRegularSamples(count: 20, fps: 120, into: sampler)
        sampler.record(targetPresentationTimestamp: 20.0)
        sampler.record(targetPresentationTimestamp: 20.0 + 1.0 / 60.0)
        sampler.record(targetPresentationTimestamp: 20.0 + 2.0 / 60.0)
        sampler.record(targetPresentationTimestamp: 20.0 + 3.0 / 60.0)

        let snapshot = try XCTUnwrap(sampler.snapshot())

        XCTAssertEqual(snapshot.sampleCount, 3)
        XCTAssertEqual(snapshot.estimatedFramesPerSecond, 60, accuracy: 0.01)
    }

    func testRollingWindowHonorsMaximumSampleCount() throws {
        let sampler = PresentationTimingSampler(maximumSampleCount: 10)
        recordRegularSamples(count: 41, fps: 90, into: sampler)

        let snapshot = try XCTUnwrap(sampler.snapshot())

        XCTAssertEqual(snapshot.sampleCount, 10)
        XCTAssertEqual(snapshot.estimatedFramesPerSecond, 90, accuracy: 0.01)
    }

    private func recordRegularSamples(
        count: Int,
        fps: Double,
        into sampler: PresentationTimingSampler
    ) {
        var timestamp = 1.0
        for _ in 0..<count {
            sampler.record(targetPresentationTimestamp: timestamp)
            timestamp += 1.0 / fps
        }
    }
}
