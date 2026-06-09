import AppKit

/// 覆盖刘海的无边框透明面板。
/// 层级用 statusBar（高于菜单栏、覆盖刘海）：不能用 screenSaver——那是 CGShieldingWindowLevel，
/// 系统会把该层级的窗口排除在拖放(drag & drop)之外，导致拖文件到岛收不到事件。
/// 代价：statusBar 低于全屏应用层级，全屏下可能被盖住（拖放可用性优先）。
final class NotchWindow: NSPanel {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none   // frame 变化不要系统动画，动画交给 SwiftUI
    }

    // 面板内按钮可点击且不抢占其他应用焦点
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
