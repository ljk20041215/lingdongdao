import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 临时：屏幕顶部居中放一个黑色胶囊，验证构建与运行链路。Task 4 替换为真实刘海窗口。
        guard let screen = NSScreen.main else { return }
        let rect = CGRect(x: screen.frame.midX - 100, y: screen.frame.maxY - 60, width: 200, height: 36)
        let w = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.level = .floating
        w.contentView = NSHostingView(
            rootView: Text("lindongdao")
                .foregroundStyle(.white)
                .frame(width: 200, height: 36)
                .background(Color.black, in: Capsule())
        )
        w.orderFrontRegardless()
        window = w
    }
}
