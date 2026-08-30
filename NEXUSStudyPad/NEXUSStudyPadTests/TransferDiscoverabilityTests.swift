import XCTest
@testable import NEXUSStudyPad

final class TransferDiscoverabilityTests: XCTestCase {
    func testTransferRouteRemainsVisibleWithExplicitNameAndIcon() {
        XCTAssertTrue(AppRoute.allCases.contains(.transfer))
        XCTAssertEqual(AppRoute.transfer.titleText, "Mac'ten aktar")
        XCTAssertEqual(AppRoute.transfer.icon, "square.and.arrow.down.on.square")
    }

    func testTodayTransferEntryHasStableAccessibilityTargets() {
        XCTAssertEqual(TransferEntryAccessibility.cardIdentifier, "today.transfer.card")
        XCTAssertEqual(TransferEntryAccessibility.buttonIdentifier, "today.transfer.open")
    }
}
