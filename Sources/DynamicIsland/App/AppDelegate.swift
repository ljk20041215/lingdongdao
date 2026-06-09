import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandWindowController?
    private let islandVM = IslandViewModel()
    private let musicVM = MusicViewModel(provider: AppleScriptMusicProvider())
    private let shelf = ShelfStore()
    private let audioVM = AudioOutputViewModel(provider: CoreAudioOutputProvider())
    private let pages = IslandPagesModel()
    private var statusItem: NSStatusItem?

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
        controller.show(
            content: IslandRootView(
                viewModel: islandVM,
                musicVM: musicVM,
                shelf: shelf,
                audioVM: audioVM,
                pages: pages,
                notchSize: geometry.notchRect.size),
            onDragTargeted: { [weak self] targeted in
                guard let self else { return }
                self.islandVM.setDragTargeted(targeted)
                if targeted { self.pages.go(to: .shelf) }   // 拖拽悬停即跳文件页
            },
            onDropFiles: { [weak self] urls in
                guard let self else { return }
                self.islandVM.send(.dropCompleted)           // 同步保持展开
                self.pages.go(to: .shelf)
                self.shelf.add(urls: urls)                   // 满架自动抖动（见 ShelfStore.rejectBump）
            })
        self.controller = controller

        musicVM.start()
        audioVM.refresh()
        setupStatusItem()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.fill",
                                     accessibilityDescription: "lindongdao")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "退出 lindongdao",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }
}
