import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandWindowController?
    private let islandVM = IslandViewModel()
    private let musicVM = MusicViewModel(provider: AppleScriptMusicProvider())
    private let shelf = ShelfStore()

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
            musicVM: musicVM,
            shelf: shelf,
            notchSize: geometry.notchRect.size))
        self.controller = controller

        musicVM.start()
    }
}
