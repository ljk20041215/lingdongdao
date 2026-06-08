import XCTest
@testable import DynamicIsland

final class IslandViewModelTests: XCTestCase {
    /// 注入式调度器：捕获被延迟的任务，由测试决定何时执行（绕过真实时钟）。
    /// 还原队列语义：已取消的任务不执行。
    private final class ManualScheduler {
        private var pending: [DispatchWorkItem] = []
        func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) { pending.append(work) }
        func fireAll() {
            let due = pending
            pending.removeAll()
            for work in due where !work.isCancelled { work.perform() }
        }
    }

    private func makeVM() -> (IslandViewModel, ManualScheduler, () -> [IslandState]) {
        let scheduler = ManualScheduler()
        let vm = IslandViewModel(schedule: { delay, work in scheduler.schedule(delay, work) })
        var transitions: [IslandState] = []
        vm.onStateChange = { transitions.append($0) }
        return (vm, scheduler, { transitions })
    }

    func testHoverEnterExpandsImmediately() {
        let (vm, _, _) = makeVM()
        vm.setHovered(true)
        XCTAssertEqual(vm.state, .expanded)
    }

    /// 核心回归：窗口展开瞬间 AppKit 误报一次 mouseExited(false)，紧跟真实 mouseEntered(true)。
    /// 去抖必须吸收这次假退出——绝不能产生 collapsed 跳变（否则刘海可见地「抖一下」）。
    func testSpuriousExitDuringResizeNeverCollapses() {
        let (vm, scheduler, transitions) = makeVM()
        vm.setHovered(true)    // 展开（窗口随之放大）
        vm.setHovered(false)   // 假退出：collapse 被延迟
        vm.setHovered(true)    // 缩放后立即再进入：取消延迟的 collapse
        scheduler.fireAll()    // 时钟到点：被取消的任务不执行
        XCTAssertEqual(vm.state, .expanded)
        XCTAssertEqual(transitions(), [.expanded], "假退出不得产生 collapsed 跳变")
    }

    /// 真实离开：去抖期间仍保持展开，延迟到点后才收起。
    func testRealExitCollapsesAfterDelay() {
        let (vm, scheduler, transitions) = makeVM()
        vm.setHovered(true)
        vm.setHovered(false)
        XCTAssertEqual(vm.state, .expanded, "去抖期间应仍展开")
        scheduler.fireAll()
        XCTAssertEqual(vm.state, .collapsed)
        XCTAssertEqual(transitions(), [.expanded, .collapsed])
    }

    /// 既有拖拽去抖行为：isTargeted 跨子视图边界闪一帧 false 不得收起。
    func testDragExitDebounceAbsorbsFlicker() {
        let (vm, scheduler, transitions) = makeVM()
        vm.setDragTargeted(true)
        vm.setDragTargeted(false)
        vm.setDragTargeted(true)
        scheduler.fireAll()
        XCTAssertEqual(vm.state, .dropTarget)
        XCTAssertEqual(transitions(), [.dropTarget])
    }
}
