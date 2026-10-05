import XCTest

@testable import Arithmetic

final class ArithmeticTests: XCTestCase {
    func testAdd() {
        XCTAssertEqual(Adder().add(2, 3), 5)
    }

    func testIsPositive() {
        XCTAssertTrue(Adder().isPositive(1))
        XCTAssertFalse(Adder().isPositive(-1))
    }

    func testContains() {
        XCTAssertTrue(Bounds().contains(5, from: 1, to: 9))
        XCTAssertFalse(Bounds().contains(10, from: 1, to: 9))
    }
}
