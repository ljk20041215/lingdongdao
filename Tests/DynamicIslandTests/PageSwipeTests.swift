import XCTest
@testable import DynamicIsland

final class PageSwipeTests: XCTestCase {
    // 约定（自然滚动）：手指左滑累计 dx 为负 → 下一页(+1)；右滑为正 → 上一页(-1)
    func testSwipeLeftGoesNext() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -50, threshold: 40), 1)
    }
    func testSwipeRightGoesPrev() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 50, threshold: 40), -1)
    }
    func testBelowThresholdNoChange() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 20, threshold: 40), 0)
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -20, threshold: 40), 0)
    }
    func testAtThresholdTriggers() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -40, threshold: 40), 1)
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 40, threshold: 40), -1)
    }
}
