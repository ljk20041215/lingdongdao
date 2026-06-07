import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandWindowController?
    private let islandVM = IslandViewModel()
    private let musicVM = MusicViewModel(provider: AppleScriptMusicProvider())

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let geometry = NotchGeometry.fromBestScreen() else {
            NSLog("lindongdao: 找不到屏幕，退出")
            NSApp.terminate(nil)
            return
        }
        let controller = IslandWindowController(geometry: geometry)
        islandVM.onStateChange = { [weak controller] state in
            controller?.apply(state: state)
        }
        controller.show(content: IslandRootView(
            viewModel: islandVM,
            notchSize: geometry.notchRect.size))
        self.controller = controller

        musicVM.start()
        // 临时调试日志（Task 8 接 UI 后删除）：
        logNowPlaying()
    }

    private func logNowPlaying() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if let info = self?.musicVM.info {
                NSLog("正在播放: %@ - %@ (%@)", info.title, info.artist,
                      info.isPlaying ? "playing" : "paused")
            } else {
                NSLog("未在播放")
            }
        }
    }
}
