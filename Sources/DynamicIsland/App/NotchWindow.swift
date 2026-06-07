import AppKit

/// 覆盖刘海的无边框透明面板。
/// 关键点：层级高于菜单栏（screenSaver）、加入所有空间、全屏辅助 → 全屏应用下依然可见。
final class NotchWindow: NSPanel {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .screenSaver
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
