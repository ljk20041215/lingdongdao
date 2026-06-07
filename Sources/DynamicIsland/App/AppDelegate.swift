import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NotchWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.fromBestScreen() else {
            NSLog("lindongdao: 找不到屏幕，退出")
            NSApp.terminate(nil)
            return
        }
        let rect = IslandLayout.collapsedWindowRect(notch: geometry.notchRect)
        let w = NotchWindow(contentRect: rect)
        // 临时内容：纯黑填充验证窗口位置盖住刘海。Task 5 替换为 IslandRootView。
        w.contentView = NSHostingView(rootView: Color.black)
        w.orderFrontRegardless()
        window = w
    }
}
