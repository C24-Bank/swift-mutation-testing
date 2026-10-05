import XCTest

@testable import Greeting

final class GreetingTests: XCTestCase {
    func testGreeting() {
        XCTAssertEqual(Greeter().greeting(for: "Ana"), "Hello, Ana")
        XCTAssertEqual(Greeter().greeting(for: ""), "Hello")
    }

    func testIsShort() {
        XCTAssertTrue(Greeter().isShort("Bo"))
        XCTAssertFalse(Greeter().isShort("Maria"))
    }

    func testShout() {
        XCTAssertEqual(Formatter().shout("hi", loud: true), "HI")
    }
}
