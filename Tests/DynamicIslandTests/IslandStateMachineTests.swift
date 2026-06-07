import XCTest
@testable import DynamicIsland

final class IslandStateMachineTests: XCTestCase {
    func testHoverExpandsFromCollapsed() {
        var m = IslandStateMachine()
        XCTAssertEqual(m.handle(.hoverChanged(true)), .expanded)
    }

    func testHoverExitCollapsesFromExpanded() {
        var m = IslandStateMachine()
        _ = m.handle(.hoverChanged(true))
        XCTAssertEqual(m.handle(.hoverChanged(false)), .collapsed)
    }

    func testDragEntersDropTargetFromAnyState() {
        var m1 = IslandStateMachine()
        XCTAssertEqual(m1.handle(.dragTargetingChanged(true)), .dropTarget)

        var m2 = IslandStateMachine()
        _ = m2.handle(.hoverChanged(true))
        XCTAssertEqual(m2.handle(.dragTargetingChanged(true)), .dropTarget)
    }

    func testDragLeavesDropTargetToCollapsed() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        XCTAssertEqual(m.handle(.dragTargetingChanged(false)), .collapsed)
    }

    func testDropCompletedShowsExpanded() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        XCTAssertEqual(m.handle(.dropCompleted), .expanded)
    }

    func testIrrelevantEventsDoNotChangeState() {
        var m = IslandStateMachine()
        XCTAssertEqual(m.handle(.hoverChanged(false)), .collapsed)   // 收起时移出鼠标：不变
        XCTAssertEqual(m.handle(.dropCompleted), .collapsed)         // 收起时收到 drop 完成：不变
    }

    // 拖拽中 onHover 可能闪 false：dropTarget 不得因此收起
    func testHoverExitDoesNotLeaveDropTarget() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        XCTAssertEqual(m.handle(.hoverChanged(false)), .dropTarget)
    }

    // 投放完成展开后，延迟到达的拖拽离开事件不得收起面板
    func testLateDragExitDoesNotCollapseAfterDrop() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        _ = m.handle(.dropCompleted)
        XCTAssertEqual(m.handle(.dragTargetingChanged(false)), .expanded)
    }
}
