import Foundation

/// 包装纯状态机，负责：把状态发布给 SwiftUI、把变化回调给窗口控制器、
/// 以及拖拽悬停标志在区域切换瞬间的 false 抖动消除（延迟 0.15s 生效）。
final class IslandViewModel: ObservableObject {
    @Published private(set) var state: IslandState = .collapsed
    var onStateChange: ((IslandState) -> Void)?

    private var machine = IslandStateMachine()
    private var pendingDragExit: DispatchWorkItem?

    func send(_ event: IslandEvent) {
        let new = machine.handle(event)
        guard new != state else { return }
        state = new
        onStateChange?(new)
    }

    /// SwiftUI onDrop 的 isTargeted 在拖拽跨过子视图边界时会闪一帧 false，
    /// 直接收起会导致岛在拖拽中闪烁，所以 false 延迟生效、true 立即生效。
    func setDragTargeted(_ targeted: Bool) {
        pendingDragExit?.cancel()
        if targeted {
            send(.dragTargetingChanged(true))
        } else {
            let work = DispatchWorkItem { [weak self] in
                self?.send(.dragTargetingChanged(false))
            }
            pendingDragExit = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }

}
