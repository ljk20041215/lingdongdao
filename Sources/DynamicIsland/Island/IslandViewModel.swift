import Foundation

/// 包装纯状态机：把状态发布给 SwiftUI、把变化回调给窗口控制器，
/// 并对「离开」做去抖。窗口在展开/收起瞬间会改变尺寸，AppKit 会因此误报一次
/// mouseExited，若直接收起就会看到刘海「抖一下」；离开延迟生效、进入立即生效，
/// 可吸收这种瞬时假退出。拖拽悬停同理（isTargeted 跨子视图边界会闪一帧 false）。
final class IslandViewModel: ObservableObject {
    /// 延迟调度（可注入以便测试）。work 由调用方持有以便取消。
    typealias Schedule = (_ delay: TimeInterval, _ work: DispatchWorkItem) -> Void

    @Published private(set) var state: IslandState = .collapsed
    var onStateChange: ((IslandState) -> Void)?

    private var machine = IslandStateMachine()
    private var pendingHoverExit: DispatchWorkItem?
    private var pendingDragExit: DispatchWorkItem?
    private let schedule: Schedule

    /// 假退出吸收窗口：窗口缩放引发假 mouseExited 后约 150~220ms 内会再次进入（实测）
    static let hoverExitDebounce: TimeInterval = 0.25
    static let dragExitDebounce: TimeInterval = 0.15

    init(schedule: @escaping Schedule = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }) {
        self.schedule = schedule
    }

    func send(_ event: IslandEvent) {
        let new = machine.handle(event)
        guard new != state else { return }
        state = new
        onStateChange?(new)
    }

    /// 悬停：进入立即展开；离开延迟生效，吸收窗口缩放引发的假退出（根治刘海抖动）
    func setHovered(_ hovered: Bool) {
        pendingHoverExit?.cancel()
        if hovered {
            send(.hoverChanged(true))
        } else {
            let work = DispatchWorkItem { [weak self] in self?.send(.hoverChanged(false)) }
            pendingHoverExit = work
            schedule(Self.hoverExitDebounce, work)
        }
    }

    /// 文件拖拽悬停：进入立即生效，离开延迟生效消除跨子视图边界的闪烁
    func setDragTargeted(_ targeted: Bool) {
        pendingDragExit?.cancel()
        if targeted {
            send(.dragTargetingChanged(true))
        } else {
            let work = DispatchWorkItem { [weak self] in self?.send(.dragTargetingChanged(false)) }
            pendingDragExit = work
            schedule(Self.dragExitDebounce, work)
        }
    }
}
