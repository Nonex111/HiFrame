import CoreGraphics
import XCTest
@testable import HiFrame

final class SignalSurfaceGeometryTests: XCTestCase {
    func testSignalSurfaceIsOnePointCenteredOnMainDisplay() {
        let rect = signalSurfaceRect(
            in: CGRect(x: 0, y: 0, width: 1_512, height: 982),
            position: .center
        )

        XCTAssertEqual(rect, CGRect(x: 755.5, y: 490.5, width: 1, height: 1))
    }

    func testSignalSurfaceUsesTheSelectedDisplaysCoordinateSpace() {
        let rect = signalSurfaceRect(
            in: CGRect(x: -1_920, y: -100, width: 1_920, height: 1_080),
            position: .center
        )

        XCTAssertEqual(rect, CGRect(x: -960.5, y: 439.5, width: 1, height: 1))
    }

    func testSignalSurfaceCanUseBothLowerCorners() {
        let frame = CGRect(x: -1_920, y: -100, width: 1_920, height: 1_080)

        XCTAssertEqual(
            signalSurfaceRect(in: frame, position: .lowerLeft),
            CGRect(x: -1_919, y: -99, width: 1, height: 1)
        )
        XCTAssertEqual(
            signalSurfaceRect(in: frame, position: .lowerRight),
            CGRect(x: -2, y: -99, width: 1, height: 1)
        )
    }
}
