enum IslandState: Equatable {
    case collapsed   // 与刘海融为一体
    case expanded    // 悬停展开的面板
    case dropTarget  // 文件拖拽悬停，高亮投放区
}

enum IslandEvent: Equatable {
    case hoverChanged(Bool)         // 鼠标进入/离开岛
    case dragTargetingChanged(Bool) // 文件拖拽悬停进入/离开岛
    case dropCompleted              // 文件已投放
}

/// 纯状态机：不持有定时器/视图，便于穷举测试。
struct IslandStateMachine {
    private(set) var state: IslandState = .collapsed

    @discardableResult
    mutating func handle(_ event: IslandEvent) -> IslandState {
        switch (state, event) {
        case (.collapsed, .hoverChanged(true)):
            state = .expanded
        case (.expanded, .hoverChanged(false)):
            state = .collapsed
        case (_, .dragTargetingChanged(true)):
            state = .dropTarget
        case (.dropTarget, .dragTargetingChanged(false)):
            state = .collapsed
        case (.dropTarget, .dropCompleted):
            state = .expanded
        default:
            break
        }
        return state
    }
}
