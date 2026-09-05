import ServiceManagement
import XCTest
@testable import HiFrame

final class LoginItemManagerTests: XCTestCase {
    func testInitializationDoesNotRegisterAndReadsExternalChanges() {
        let service = FakeService()
        let manager = service.manager()
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(service.registerCalls, 0)
        service.status = .enabled
        XCTAssertEqual(manager.status, .enabled)
        service.status = .requiresApproval
        XCTAssertEqual(manager.status, .requiresApproval)
    }

    func testEnableAndDisableAreIdempotent() throws {
        let service = FakeService()
        let manager = service.manager()
        try manager.setEnabled(true)
        try manager.setEnabled(true)
        XCTAssertEqual(manager.status, .enabled)
        XCTAssertEqual(service.registerCalls, 1)
        try manager.setEnabled(false)
        try manager.setEnabled(false)
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(service.unregisterCalls, 1)
    }

    func testPendingApprovalIsNotReportedAsEnabledAndCanBeCancelled() throws {
        let service = FakeService()
        service.registrationResult = .requiresApproval
        let manager = service.manager()
        try manager.setEnabled(true)
        XCTAssertEqual(manager.status, .requiresApproval)
        try manager.setEnabled(true)
        XCTAssertEqual(service.registerCalls, 1)
        try manager.setEnabled(false)
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(service.unregisterCalls, 1)
    }

    func testRegistrationFailureDoesNotInventEnabledState() {
        let service = FakeService()
        service.shouldFail = true
        let manager = service.manager()
        XCTAssertThrowsError(try manager.setEnabled(true))
        XCTAssertEqual(manager.status, .notRegistered)
    }

    func testUnregistrationFailurePreservesSystemState() {
        let service = FakeService()
        service.status = .enabled
        service.shouldFail = true
        let manager = service.manager()
        XCTAssertThrowsError(try manager.setEnabled(false))
        XCTAssertEqual(manager.status, .enabled)
    }

    func testCommandLineExecutableCannotRegister() {
        let service = FakeService()
        let manager = service.manager(isAppBundle: false)
        XCTAssertThrowsError(try manager.setEnabled(true))
        XCTAssertEqual(service.registerCalls, 0)
    }

    private final class FakeService {
        var status: SMAppService.Status = .notRegistered
        var registrationResult: SMAppService.Status = .enabled
        var registerCalls = 0
        var unregisterCalls = 0
        var shouldFail = false

        func manager(isAppBundle: Bool = true) -> LoginItemManager {
            LoginItemManager(
                isAppBundle: isAppBundle,
                readStatus: { self.status },
                register: {
                    self.registerCalls += 1
                    if self.shouldFail { throw Failure.expected }
                    self.status = self.registrationResult
                },
                unregister: {
                    self.unregisterCalls += 1
                    if self.shouldFail { throw Failure.expected }
                    self.status = .notRegistered
                }
            )
        }

        enum Failure: Error { case expected }
    }
}
