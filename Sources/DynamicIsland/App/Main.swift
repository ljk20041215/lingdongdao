import AppKit

@main
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // 菜单栏级应用：不占 Dock、不出现在 ⌘Tab
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
