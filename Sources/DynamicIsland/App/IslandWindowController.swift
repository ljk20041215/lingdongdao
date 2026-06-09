import AppKit
import SwiftUI

/// 持有窗口与几何信息，根据岛状态切换窗口 frame。
/// 展开：先放大窗口（透明，无视觉跳变），SwiftUI 弹簧动画负责可见形变。
/// 收起：等 SwiftUI 收起动画播完（0.4s）再缩小窗口，避免动画被裁剪。
final class IslandWindowController {
    let window: NotchWindow
    let geometry: NotchGeometry
    private var currentState: IslandState = .collapsed
    private var pendingShrink: DispatchWorkItem?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
        self.window = NotchWindow(
            contentRect: IslandLayout.collapsedWindowRect(notch: geometry.notchRect))
    }

    /// 文件投放在 AppKit 层接收（见 FileDropView）；SwiftUI 内容叠在其上正常处理鼠标/滚动。
    func show<Content: View>(content: Content,
                             onDragTargeted: @escaping (Bool) -> Void,
                             onDropFiles: @escaping ([URL]) -> Void) {
        let dropView = FileDropView(onTargeted: onDragTargeted, onDrop: onDropFiles)
        window.contentView = dropView
        let host = NSHostingView(rootView: content)
        host.translatesAutoresizingMaskIntoConstraints = false
        dropView.addSubview(host)
        NSLayoutConstraint.activate([      // 钉满 dropView，随窗口缩放原子同步，避免收起时抖动
            host.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: dropView.trailingAnchor),
            host.topAnchor.constraint(equalTo: dropView.topAnchor),
            host.bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
        ])
        window.orderFrontRegardless()
    }

    func apply(state: IslandState) {
        currentState = state
        pendingShrink?.cancel()
        let target = IslandLayout.windowRect(for: state, notch: geometry.notchRect)
        if state == .collapsed {
            // 等 SwiftUI 收起动画播完再缩小窗口；新状态到来时取消，避免陈旧任务裁剪动画
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.currentState == .collapsed else { return }
                self.window.setFrame(target, display: true)
            }
            pendingShrink = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        } else {
            window.setFrame(target, display: true)
        }
    }
}
