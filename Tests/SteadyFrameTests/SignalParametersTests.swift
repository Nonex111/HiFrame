import XCTest
@testable import SteadyFrame

final class SignalParametersTests: XCTestCase {
    func testFixedSignalUsesEightCodeValuesBetweenFrames() {
        XCTAssertEqual(
            SignalParameters.frameToFrameLuminanceDelta,
            8.0 / 255.0,
            accuracy: 0.000_001
        )
    }
}
