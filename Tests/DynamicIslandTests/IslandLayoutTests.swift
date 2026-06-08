import XCTest
@testable import DynamicIsland

final class IslandLayoutTests: XCTestCase {
    let notch = CGRect(x: 622, y: 950, width: 268, height: 32)

    func testCollapsedWindowWrapsNotchWithChips() {
        let r = IslandLayout.collapsedWindowRect(notch: notch)
        XCTAssertEqual(r, CGRect(x: 566, y: 950, width: 380, height: 32)) // 两侧各 +56
    }

    func testExpandedWindowIsCenteredUnderNotchTop() {
        let r = IslandLayout.expandedWindowRect(notch: notch)
        // 宽度取「面板宽」与「刘海+两翼」的较大者：面板比刘海窄时也绝不露出刘海两侧
        XCTAssertEqual(r.width, max(IslandLayout.expandedSize.width,
                                    notch.width + IslandLayout.chipWidth * 2))
        XCTAssertEqual(r.height, IslandLayout.expandedSize.height)
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
