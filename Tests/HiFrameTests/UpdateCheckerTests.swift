import Foundation
import XCTest
@testable import HiFrame

final class UpdateCheckerTests: XCTestCase {
    func testNumericVersionOrderingAndNormalization() throws {
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("v0.4.10")), try XCTUnwrap(AppVersion("0.4.9")))
        XCTAssertGreaterThan(try XCTUnwrap(AppVersion("1.0.0")), try XCTUnwrap(AppVersion("0.99.99")))
        XCTAssertEqual(AppVersion("v1.2"), AppVersion("1.2.0"))
        for invalid in ["", "v", "1..2", "1.2-beta", "1.2.3/evil", "1.2.3.4.5", "1.999999999999999999999999"] {
            XCTAssertNil(AppVersion(invalid), invalid)
        }
    }

    @MainActor func testNewReleaseAndTrustedDestination() async throws {
        let fixture = Fixture()
        let checker = fixture.checker()
        guard case .available(let release) = try await checker.check(manual: true) else {
            return XCTFail("Expected a new version")
        }
        XCTAssertEqual(release.tagName, "v0.4.10")
        XCTAssertEqual(release.pageURL.absoluteString, "https://github.com/Nonex111/SteadyFrame/releases/tag/v0.4.10")
        XCTAssertFalse(checker.isChecking)
    }

    @MainActor func testEqualAndOlderReleaseDoNotOfferDowngrade() async throws {
        let fixture = Fixture()
        for tag in ["v0.4.9", "v0.4.8"] {
            fixture.tag = tag
            guard case .upToDate = try await fixture.checker().check(manual: true) else {
                return XCTFail("Should not offer \(tag)")
            }
        }
    }

    @MainActor func testDailyThrottleSurvivesRelaunchAndManualCheckBypassesIt() async throws {
        let fixture = Fixture()
        _ = try await fixture.checker().check(manual: false)
        let skipped = try await fixture.checker().check(manual: false)
        XCTAssertNil(skipped)
        XCTAssertEqual(fixture.calls, 1)
        guard case .available = try await fixture.checker().check(manual: true) else {
            return XCTFail("Manual check must bypass throttle and repeated-version suppression")
        }
        XCTAssertEqual(fixture.calls, 2)
    }

    @MainActor func testSameVersionPromptsOnceButLaterVersionPromptsAgain() async throws {
        let fixture = Fixture()
        _ = try await fixture.checker().check(manual: false)
        fixture.date.addTimeInterval(UpdateChecker.checkInterval)
        let repeated = try await fixture.checker().check(manual: false)
        XCTAssertNil(repeated)
        XCTAssertEqual(fixture.calls, 2)
        fixture.date.addTimeInterval(UpdateChecker.checkInterval)
        fixture.tag = "v0.5.0"
        guard case .available = try await fixture.checker().check(manual: false) else {
            return XCTFail("Expected next version prompt")
        }
    }

    @MainActor func testFailuresAreNotReportedAsUpToDateAndCanBeRetried() async throws {
        let fixture = Fixture()
        let checker = fixture.checker()
        for code in [403, 429, 404, 500] {
            fixture.statusCode = code
            do {
                _ = try await checker.check(manual: true)
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertFalse(checker.isChecking)
            }
        }
        fixture.statusCode = 200
        guard case .available = try await checker.check(manual: true) else {
            return XCTFail("Expected recovery")
        }
    }

    @MainActor func testUnexpectedOrUnstableReleaseRedirectIsRejected() async throws {
        let fixture = Fixture()
        for destination in [
            "https://github.com/Nonex111/SteadyFrame/releases/latest",
            "https://github.com/login",
            "https://example.com/Nonex111/SteadyFrame/releases/tag/v9.0.0",
            "https://github.com/Other/Repo/releases/tag/v9.0.0",
            "http://github.com/Nonex111/SteadyFrame/releases/tag/v9.0.0",
            "https://github.com/Nonex111/SteadyFrame/releases/tag/v1.0.0-beta",
            "https://github.com/Nonex111/SteadyFrame/releases/tag/bad",
            "https://github.com/Nonex111/SteadyFrame/releases/tag/v1.0.0?redirect=other"
        ] {
            fixture.destination = URL(string: destination)!
            do {
                _ = try await fixture.checker().check(manual: true)
                XCTFail("Expected invalid release failure")
            } catch { }
        }
    }

    @MainActor func testLiveReleaseCheck() async throws {
        guard ProcessInfo.processInfo.environment["STEADYFRAME_LIVE_UPDATE_CHECK"] == "1" else {
            throw XCTSkip("Opt-in real GitHub request")
        }
        let fixture = Fixture()
        let checker = UpdateChecker(currentVersion: "0.0.0", defaults: fixture.defaults)
        guard case .available(let release) = try await checker.check(manual: true) else {
            return XCTFail("Expected the published release")
        }
        XCTAssertNotNil(AppVersion(release.tagName))
        print("Live GitHub release verified: \(release.tagName), \(release.pageURL)")
    }

    @MainActor func testConcurrentChecksMakeOneRequest() async throws {
        let fixture = Fixture()
        var continuation: CheckedContinuation<Void, Never>?
        let checker = UpdateChecker(currentVersion: "0.4.9", defaults: fixture.defaults, fetch: {
            await withCheckedContinuation { continuation = $0 }
            return fixture.response()
        })
        let first = Task { try await checker.check(manual: true) }
        while continuation == nil { await Task.yield() }
        XCTAssertTrue(checker.isChecking)
        let duplicate = try await checker.check(manual: true)
        XCTAssertNil(duplicate)
        continuation?.resume()
        _ = try await first.value
        XCTAssertEqual(fixture.calls, 1)
        XCTAssertFalse(checker.isChecking)
    }

    @MainActor private final class Fixture {
        let suiteName = "HiFrameUpdateTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        var date = Date(timeIntervalSince1970: 1_000_000)
        var tag = "v0.4.10"
        var statusCode = 200
        var destination: URL?
        var calls = 0

        init() { defaults = UserDefaults(suiteName: suiteName)! }
        deinit { defaults.removePersistentDomain(forName: suiteName) }

        func checker() -> UpdateChecker {
            UpdateChecker(currentVersion: "0.4.9", defaults: defaults, now: { self.date }, fetch: { self.response() })
        }

        func response() -> (Data, URLResponse) {
            calls += 1
            let url = destination ?? UpdateChecker.releasesURL.appendingPathComponent("tag").appendingPathComponent(tag)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
    }
}
