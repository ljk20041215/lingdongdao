import XCTest
@testable import DynamicIsland

final class IslandLayoutTests: XCTestCase {
    let notch = CGRect(x: 622, y: 950, width: 268, height: 32)

    func testCollapsedWindowWrapsNotchWithChips() {
        let r = IslandLayout.collapsedWindowRect(notch: notch)
        XCTAssertEqual(r, CGRect(x: 566, y: 950, width: 380, height: 32)) // 两侧各 +56
    }

    func testExpandedWindowSameWidthAsCollapsed() {
        let r = IslandLayout.expandedWindowRect(notch: notch)
        // 与收起态同宽同 x：收起/展开纯高度变化，无横向跳变
        XCTAssertEqual(r.width, notch.width + IslandLayout.chipWidth * 2)
        XCTAssertEqual(r.width, IslandLayout.collapsedWindowRect(notch: notch).width)
        XCTAssertEqual(r.minX, IslandLayout.collapsedWindowRect(notch: notch).minX)
        XCTAssertEqual(r.height, IslandLayout.expandedHeight)
        XCTAssertEqual(r.midX, notch.midX)            // 水平居中对齐刘海
        XCTAssertEqual(r.maxY, notch.maxY)            // 顶边贴屏幕顶
    }

    func testExpandedWindowNeverNarrowerThanCollapsed() {
        let wideNotch = CGRect(x: 0, y: 950, width: 800, height: 32)
        let r = IslandLayout.expandedWindowRect(notch: wideNotch)
        XCTAssertGreaterThanOrEqual(r.width, IslandLayout.collapsedWindowRect(notch: wideNotch).width)
    }

    func testWindowRectDispatchesByState() {
        XCTAssertEqual(IslandLayout.windowRect(for: .collapsed, notch: notch),
                       IslandLayout.collapsedWindowRect(notch: notch))
        XCTAssertEqual(IslandLayout.windowRect(for: .expanded, notch: notch),
                       IslandLayout.expandedWindowRect(notch: notch))
        XCTAssertEqual(IslandLayout.windowRect(for: .dropTarget, notch: notch),
                       IslandLayout.expandedWindowRect(notch: notch))
    }
}
