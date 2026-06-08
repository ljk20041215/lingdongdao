import XCTest
@testable import DynamicIsland

final class IslandPagesModelTests: XCTestCase {
    func testDefaultIsMusic() {
        XCTAssertEqual(IslandPagesModel().current, .music)
    }
    func testGoSetsCurrent() {
        let m = IslandPagesModel()
        m.go(to: .shelf)
        XCTAssertEqual(m.current, .shelf)
    }
    func testAdvanceMovesOnePage() {
        let m = IslandPagesModel()
        m.advance(by: 1)
        XCTAssertEqual(m.current, .shelf)
    }
    func testAdvanceClampsAtStart() {
        let m = IslandPagesModel()           // .music = 第 0 页
        m.advance(by: -1)
        XCTAssertEqual(m.current, .music)    // 不回绕
    }
    func testAdvanceClampsAtEnd() {
        let m = IslandPagesModel()
        m.go(to: .shelf)                     // 末页
        m.advance(by: 1)
        XCTAssertEqual(m.current, .shelf)    // 不回绕
    }
}
