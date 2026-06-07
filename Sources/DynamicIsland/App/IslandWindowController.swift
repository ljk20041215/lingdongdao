import AppKit
import SwiftUI

/// 持有窗口与几何信息，根据岛状态切换窗口 frame。
/// 展开：先放大窗口（透明，无视觉跳变），SwiftUI 弹簧动画负责可见形变。
/// 收起：等 SwiftUI 收起动画播完（0.4s）再缩小窗口，避免动画被裁剪。
final class IslandWindowController {
    let window: NotchWindow
    let geometry: NotchGeometry
    private var currentState: IslandState = .collapsed

    init(geometry: NotchGeometry) {
        self.geometry = geometry
        self.window = NotchWindow(
            contentRect: IslandLayout.collapsedWindowRect(notch: geometry.notchRect))
    }

    func show<Content: View>(content: Content) {
        window.contentView = NSHostingView(rootView: content)
        window.orderFrontRegardless()
    }

    func apply(state: IslandState) {
        currentState = state
        let target = IslandLayout.windowRect(for: state, notch: geometry.notchRect)
        if state == .collapsed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, self.currentState == .collapsed else { return }
                self.window.setFrame(target, display: true)
            }
        } else {
            window.setFrame(target, display: true)
        }
    }
}
