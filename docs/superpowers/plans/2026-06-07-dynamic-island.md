# macOS 灵动岛（lindongdao）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在带刘海的 MacBook 上实现一个常驻灵动岛应用：悬停展开，左侧显示音乐播放（Apple Music / Spotify），右侧是文件中转站（拖入暂存、拖出使用）。

**Architecture:** SwiftPM 可执行包。AppKit 负责窗口层（`NSPanel` 无边框透明窗口、层级高于菜单栏、全屏可见、随状态调整 frame），SwiftUI 负责全部界面与弹簧动画。纯逻辑（刘海几何、状态机、AppleScript 解析、文件架数据层）全部 TDD；窗口与动画行为靠人工验收清单。

**Tech Stack:** Swift 5.9+ / SwiftUI / AppKit / NSAppleScript / QuickLookThumbnailing / XCTest。无第三方依赖。最低系统 macOS 14。

**对应设计文档:** `docs/superpowers/specs/2026-06-07-dynamic-island-design.md`

---

## 全局须知（执行每个任务前先读）

- 工作目录：`~/Desktop/lindongdao`（git 仓库已初始化，main 分支）。
- 构建：`swift build`；测试：`swift test`；运行：`swift run lindongdao`（前台运行，Ctrl+C 退出）。
- **人工验收步骤**标记为 `【人工】`：执行者运行应用后请用户确认，或自己截图观察。无法自动断言的 UI 行为不写假测试。
- 首次从终端控制音乐时，系统会弹"终端想要控制 Music/Spotify"的自动化授权框——这是预期行为，点允许。
- AppleScript 的 `tell application "X"` 会**启动未运行的应用**。所有音乐脚本执行前必须先用 `NSRunningApplication` 检查目标应用是否在运行（代码已体现，不要删掉这个检查）。
- 已知取舍：收起态窗口比刘海每侧宽 56pt（露出音乐小封面/波形）。该区域理论上可能遮挡紧贴刘海的菜单栏图标，实际 macOS 不会把状态图标排到刘海边缘，可接受。

## 文件结构总览

```
lindongdao/
├── Package.swift
├── .gitignore
├── README.md                                  (Task 11)
├── scripts/
│   ├── make_app.sh                            (Task 11)
│   └── Info.plist                             (Task 11)
├── Sources/DynamicIsland/
│   ├── App/
│   │   ├── Main.swift                         (Task 1)
│   │   ├── AppDelegate.swift                  (Task 1, 4, 7, 8, 10, 11 修改)
│   │   ├── NotchWindow.swift                  (Task 4)
│   │   └── IslandWindowController.swift       (Task 5)
│   ├── Support/
│   │   └── NotchGeometry.swift                (Task 2)
│   ├── Island/
│   │   ├── IslandState.swift                  (Task 3)
│   │   ├── IslandLayout.swift                 (Task 4)
│   │   ├── IslandViewModel.swift              (Task 5)
│   │   ├── IslandRootView.swift               (Task 5, 8, 10 修改)
│   │   ├── CollapsedIslandView.swift          (Task 5, 8 修改)
│   │   ├── ExpandedPanelView.swift            (Task 5, 8, 10 修改)
│   │   ├── WaveformView.swift                 (Task 8)
│   │   └── ShakeEffect.swift                  (Task 10)
│   ├── Music/
│   │   ├── NowPlayingInfo.swift               (Task 6)
│   │   ├── NowPlayingParser.swift             (Task 6)
│   │   ├── NowPlayingProvider.swift           (Task 6)
│   │   ├── AppleScriptRunner.swift            (Task 7)
│   │   ├── AppleScriptMusicProvider.swift     (Task 7)
│   │   ├── MusicViewModel.swift               (Task 7)
│   │   └── MusicPanelView.swift               (Task 8)
│   └── Shelf/
│       ├── ShelfItem.swift                    (Task 9)
│       ├── ShelfStore.swift                   (Task 9)
│       ├── ThumbnailLoader.swift              (Task 10)
│       └── ShelfPanelView.swift               (Task 10)
└── Tests/DynamicIslandTests/
    ├── SmokeTests.swift                       (Task 1)
    ├── NotchGeometryTests.swift               (Task 2)
    ├── IslandStateMachineTests.swift          (Task 3)
    ├── IslandLayoutTests.swift                (Task 4)
    ├── NowPlayingParserTests.swift            (Task 6)
    └── ShelfStoreTests.swift                  (Task 9)
```

---

### Task 1: SwiftPM 项目骨架

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/DynamicIsland/App/Main.swift`
- Create: `Sources/DynamicIsland/App/AppDelegate.swift`
- Create: `Tests/DynamicIslandTests/SmokeTests.swift`

- [ ] **Step 1: 创建 `.gitignore`**

```gitignore
.build/
.swiftpm/
build/
*.app
.DS_Store
```

- [ ] **Step 2: 创建 `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lindongdao",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "lindongdao", targets: ["DynamicIsland"])
    ],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "Sources/DynamicIsland"
        ),
        .testTarget(
            name: "DynamicIslandTests",
            dependencies: ["DynamicIsland"],
            path: "Tests/DynamicIslandTests"
        ),
    ]
)
```

注意：入口用 `@main`（下一步），**不要**创建 `main.swift`——顶层代码文件会导致测试目标无法 `@testable import` 可执行目标。

- [ ] **Step 3: 创建 `Sources/DynamicIsland/App/Main.swift`**

```swift
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
```

- [ ] **Step 4: 创建 `Sources/DynamicIsland/App/AppDelegate.swift`（临时验证窗口，Task 4 会替换）**

```swift
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
```

- [ ] **Step 5: 创建 `Tests/DynamicIslandTests/SmokeTests.swift`**

```swift
import XCTest
@testable import DynamicIsland

final class SmokeTests: XCTestCase {
    func testTargetLinks() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 6: 构建并跑测试**

Run: `swift build && swift test`
Expected: `Build complete!`，测试 `Executed 1 test, with 0 failures`。
若报错 `xcrun: error`，先执行 `sudo xcode-select -s /Applications/Xcode.app` 再重试。

- [ ] **Step 7: 【人工】运行验证**

Run: `swift run lindongdao`
Expected: 屏幕顶部居中出现黑色胶囊，写着 "lindongdao"。Ctrl+C 退出。

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: SwiftPM 项目骨架与最小可运行窗口"
```

---

### Task 2: NotchGeometry 刘海几何计算（TDD）

**Files:**
- Create: `Sources/DynamicIsland/Support/NotchGeometry.swift`
- Test: `Tests/DynamicIslandTests/NotchGeometryTests.swift`

坐标系约定：全部使用 AppKit 屏幕坐标（原点在**左下角**，y 向上）。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import DynamicIsland

final class NotchGeometryTests: XCTestCase {
    // 14" MacBook Pro 典型值：屏幕 1512x982 pt，安全区顶部 32pt，刘海两侧各 622pt
    func testComputesNotchRectFromScreenValues() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeTopInset: 32,
            leftAuxWidth: 622,
            rightAuxWidth: 622)
        XCTAssertTrue(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 622, y: 950, width: 268, height: 32))
    }

    func testScreenWithOriginOffset() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 100, y: 50, width: 1512, height: 982),
            safeTopInset: 32,
            leftAuxWidth: 622,
            rightAuxWidth: 622)
        XCTAssertEqual(g.notchRect, CGRect(x: 722, y: 1000, width: 268, height: 32))
    }

    // 防御：无刘海时回退为顶部居中 184x32 胶囊（spec 错误处理表）
    func testNoNotchFallback() {
        let g = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeTopInset: 0,
            leftAuxWidth: nil,
            rightAuxWidth: nil)
        XCTAssertFalse(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 868, y: 1048, width: 184, height: 32))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter NotchGeometryTests`
Expected: FAIL，`cannot find 'NotchGeometry'`（编译错误即视为红灯）。

- [ ] **Step 3: 实现 `Sources/DynamicIsland/Support/NotchGeometry.swift`**

```swift
import Foundation

/// 刘海几何信息。纯值类型，便于测试；从 NSScreen 取值的封装见下方扩展。
struct NotchGeometry: Equatable {
    /// 刘海矩形（AppKit 屏幕坐标，原点左下）
    let notchRect: CGRect
    let hasNotch: Bool

    static let fallbackSize = CGSize(width: 184, height: 32)

    static func compute(screenFrame: CGRect,
                        safeTopInset: CGFloat,
                        leftAuxWidth: CGFloat?,
                        rightAuxWidth: CGFloat?) -> NotchGeometry {
        guard safeTopInset > 0, let left = leftAuxWidth, let right = rightAuxWidth else {
            let rect = CGRect(x: screenFrame.midX - fallbackSize.width / 2,
                              y: screenFrame.maxY - fallbackSize.height,
                              width: fallbackSize.width,
                              height: fallbackSize.height)
            return NotchGeometry(notchRect: rect, hasNotch: false)
        }
        let rect = CGRect(x: screenFrame.minX + left,
                          y: screenFrame.maxY - safeTopInset,
                          width: screenFrame.width - left - right,
                          height: safeTopInset)
        return NotchGeometry(notchRect: rect, hasNotch: true)
    }
}

#if canImport(AppKit)
import AppKit

extension NotchGeometry {
    /// 优先选有刘海的内建屏
    static func fromBestScreen() -> NotchGeometry? {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else { return nil }
        return compute(screenFrame: screen.frame,
                       safeTopInset: screen.safeAreaInsets.top,
                       leftAuxWidth: screen.auxiliaryTopLeftArea?.width,
                       rightAuxWidth: screen.auxiliaryTopRightArea?.width)
    }
}
#endif
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter NotchGeometryTests`
Expected: PASS，3 个测试全绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/DynamicIsland/Support/NotchGeometry.swift Tests/DynamicIslandTests/NotchGeometryTests.swift
git commit -m "feat: 刘海几何计算（含无刘海回退）"
```

---

### Task 3: 岛状态机（TDD）

**Files:**
- Create: `Sources/DynamicIsland/Island/IslandState.swift`
- Test: `Tests/DynamicIslandTests/IslandStateMachineTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import DynamicIsland

final class IslandStateMachineTests: XCTestCase {
    func testHoverExpandsFromCollapsed() {
        var m = IslandStateMachine()
        XCTAssertEqual(m.handle(.hoverChanged(true)), .expanded)
    }

    func testHoverExitCollapsesFromExpanded() {
        var m = IslandStateMachine()
        _ = m.handle(.hoverChanged(true))
        XCTAssertEqual(m.handle(.hoverChanged(false)), .collapsed)
    }

    func testDragEntersDropTargetFromAnyState() {
        var m1 = IslandStateMachine()
        XCTAssertEqual(m1.handle(.dragTargetingChanged(true)), .dropTarget)

        var m2 = IslandStateMachine()
        _ = m2.handle(.hoverChanged(true))
        XCTAssertEqual(m2.handle(.dragTargetingChanged(true)), .dropTarget)
    }

    func testDragLeavesDropTargetToCollapsed() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        XCTAssertEqual(m.handle(.dragTargetingChanged(false)), .collapsed)
    }

    func testDropCompletedShowsExpanded() {
        var m = IslandStateMachine()
        _ = m.handle(.dragTargetingChanged(true))
        XCTAssertEqual(m.handle(.dropCompleted), .expanded)
    }

    func testIrrelevantEventsDoNotChangeState() {
        var m = IslandStateMachine()
        XCTAssertEqual(m.handle(.hoverChanged(false)), .collapsed)   // 收起时移出鼠标：不变
        XCTAssertEqual(m.handle(.dropCompleted), .collapsed)         // 收起时收到 drop 完成：不变
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter IslandStateMachineTests`
Expected: FAIL（`cannot find 'IslandStateMachine'`）。

- [ ] **Step 3: 实现 `Sources/DynamicIsland/Island/IslandState.swift`**

```swift
import Foundation

enum IslandState: Equatable {
    case collapsed   // 与刘海融为一体
    case expanded    // 悬停展开的面板
    case dropTarget  // 文件拖拽悬停，高亮投放区
}

enum IslandEvent: Equatable {
    case hoverChanged(Bool)         // 鼠标进入/离开岛
    case dragTargetingChanged(Bool) // 文件拖拽悬停进入/离开岛
    case dropCompleted              // 文件已投放
}

/// 纯状态机：不持有定时器/视图，便于穷举测试。
struct IslandStateMachine {
    private(set) var state: IslandState = .collapsed

    @discardableResult
    mutating func handle(_ event: IslandEvent) -> IslandState {
        switch (state, event) {
        case (.collapsed, .hoverChanged(true)):
            state = .expanded
        case (.expanded, .hoverChanged(false)):
            state = .collapsed
        case (_, .dragTargetingChanged(true)):
            state = .dropTarget
        case (.dropTarget, .dragTargetingChanged(false)):
            state = .collapsed
        case (.dropTarget, .dropCompleted):
            state = .expanded
        default:
            break
        }
        return state
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter IslandStateMachineTests`
Expected: PASS，6 个测试全绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/DynamicIsland/Island/IslandState.swift Tests/DynamicIslandTests/IslandStateMachineTests.swift
git commit -m "feat: 岛状态机（收起/展开/拖放三态）"
```

---

### Task 4: NotchWindow 与窗口布局

**Files:**
- Create: `Sources/DynamicIsland/App/NotchWindow.swift`
- Create: `Sources/DynamicIsland/Island/IslandLayout.swift`
- Test: `Tests/DynamicIslandTests/IslandLayoutTests.swift`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`（替换临时窗口）

- [ ] **Step 1: 写 IslandLayout 失败测试**

```swift
import XCTest
@testable import DynamicIsland

final class IslandLayoutTests: XCTestCase {
    let notch = CGRect(x: 622, y: 950, width: 268, height: 32)

    func testCollapsedWindowWrapsNotchWithChips() {
        let r = IslandLayout.collapsedWindowRect(notch: notch)
        XCTAssertEqual(r, CGRect(x: 566, y: 950, width: 380, height: 32)) // 两侧各 +56
    }

    func testExpandedWindowIsCenteredUnderNotchTop() {
        let r = IslandLayout.expandedWindowRect(notch: notch)
        XCTAssertEqual(r.width, IslandLayout.expandedSize.width)
        XCTAssertEqual(r.height, IslandLayout.expandedSize.height)
        XCTAssertEqual(r.midX, notch.midX)            // 水平居中对齐刘海
        XCTAssertEqual(r.maxY, notch.maxY)            // 顶边贴屏幕顶
    }

    func testExpandedWindowNeverNarrowerThanCollapsed() {
        let wideNotch = CGRect(x: 0, y: 950, width: 800, height: 32)
        let r = IslandLayout.expandedWindowRect(notch: wideNotch)
        XCTAssertGreaterThanOrEqual(r.width, IslandLayout.collapsedWindowRect(notch: wideNotch).width)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter IslandLayoutTests`
Expected: FAIL（`cannot find 'IslandLayout'`）。

- [ ] **Step 3: 实现 `Sources/DynamicIsland/Island/IslandLayout.swift`**

```swift
import Foundation

/// 窗口与面板的尺寸常量/换算。第一版不做设置界面，参数全部用常量（spec YAGNI）。
enum IslandLayout {
    /// 收起态每侧露出的"翼"宽度（迷你封面 / 波形）
    static let chipWidth: CGFloat = 56
    /// 展开面板尺寸
    static let expandedSize = CGSize(width: 640, height: 220)

    static func collapsedWindowRect(notch: CGRect) -> CGRect {
        CGRect(x: notch.minX - chipWidth,
               y: notch.minY,
               width: notch.width + chipWidth * 2,
               height: notch.height)
    }

    static func expandedWindowRect(notch: CGRect) -> CGRect {
        let width = max(expandedSize.width, notch.width + chipWidth * 2)
        return CGRect(x: notch.midX - width / 2,
                      y: notch.maxY - expandedSize.height,
                      width: width,
                      height: expandedSize.height)
    }

    static func windowRect(for state: IslandState, notch: CGRect) -> CGRect {
        switch state {
        case .collapsed: return collapsedWindowRect(notch: notch)
        case .expanded, .dropTarget: return expandedWindowRect(notch: notch)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter IslandLayoutTests`
Expected: PASS，3 个测试全绿。

- [ ] **Step 5: 创建 `Sources/DynamicIsland/App/NotchWindow.swift`**

```swift
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
```

- [ ] **Step 6: 修改 `AppDelegate.swift`，用真实刘海窗口替换临时窗口**

整个文件替换为：

```swift
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
```

- [ ] **Step 7: 构建 + 全量测试**

Run: `swift build && swift test`
Expected: Build complete，全部测试通过。

- [ ] **Step 8: 【人工】运行验证**

Run: `swift run lindongdao`
Expected:
1. 刘海两侧各延伸出 56pt 的黑色横条，与刘海融为一体（看起来像刘海变宽了）
2. 打开任意应用进全屏（如 Safari），黑条仍然可见
3. 黑条不遮挡菜单栏图标的点击（点击靠近刘海的菜单项验证）

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: 刘海覆盖窗口（层级高于菜单栏、全屏可见）"
```

---

### Task 5: 悬停展开/收起与动画接线

**Files:**
- Create: `Sources/DynamicIsland/Island/IslandViewModel.swift`
- Create: `Sources/DynamicIsland/App/IslandWindowController.swift`
- Create: `Sources/DynamicIsland/Island/IslandRootView.swift`
- Create: `Sources/DynamicIsland/Island/CollapsedIslandView.swift`
- Create: `Sources/DynamicIsland/Island/ExpandedPanelView.swift`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`

- [ ] **Step 1: 创建 `Sources/DynamicIsland/Island/IslandViewModel.swift`**

```swift
import Foundation

/// 包装纯状态机，负责：把状态发布给 SwiftUI、把变化回调给窗口控制器、
/// 以及拖拽悬停标志在区域切换瞬间的 false 抖动消除（延迟 0.15s 生效）。
final class IslandViewModel: ObservableObject {
    @Published private(set) var state: IslandState = .collapsed
    var onStateChange: ((IslandState) -> Void)?

    private var machine = IslandStateMachine()
    private var pendingDragExit: DispatchWorkItem?

    func send(_ event: IslandEvent) {
        let new = machine.handle(event)
        guard new != state else { return }
        state = new
        onStateChange?(new)
    }

    /// SwiftUI onDrop 的 isTargeted 在拖拽跨过子视图边界时会闪一帧 false，
    /// 直接收起会导致岛在拖拽中闪烁，所以 false 延迟生效、true 立即生效。
    func setDragTargeted(_ targeted: Bool) {
        pendingDragExit?.cancel()
        if targeted {
            send(.dragTargetingChanged(true))
        } else {
            let work = DispatchWorkItem { [weak self] in
                self?.send(.dragTargetingChanged(false))
            }
            pendingDragExit = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
    }
}
```

- [ ] **Step 2: 创建 `Sources/DynamicIsland/App/IslandWindowController.swift`**

```swift
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
```

- [ ] **Step 3: 创建占位的收起/展开视图**

`Sources/DynamicIsland/Island/CollapsedIslandView.swift`（Task 8 加音乐翼，先做纯黑胶囊）：

```swift
import SwiftUI

struct CollapsedIslandView: View {
    let notchSize: CGSize

    var body: some View {
        Color.black
            .frame(width: notchSize.width, height: notchSize.height)
            .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }
}
```

`Sources/DynamicIsland/Island/ExpandedPanelView.swift`（Task 8/10 填入音乐区/文件架，先做占位）：

```swift
import SwiftUI

struct ExpandedPanelView: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("音乐区").foregroundStyle(.secondary)
            Divider().overlay(.gray.opacity(0.4))
            Text("文件架").foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }
}
```

- [ ] **Step 4: 创建 `Sources/DynamicIsland/Island/IslandRootView.swift`**

```swift
import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize)
            case .expanded, .dropTarget:
                ExpandedPanelView()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
    }
}
```

- [ ] **Step 5: 修改 `AppDelegate.swift` 接线**

整个文件替换为：

```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandWindowController?
    private let islandVM = IslandViewModel()

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
    }
}
```

- [ ] **Step 6: 构建 + 全量测试**

Run: `swift build && swift test`
Expected: Build complete，全部测试通过。

- [ ] **Step 7: 【人工】运行验证**

Run: `swift run lindongdao`
Expected:
1. 默认状态：岛与刘海融为一体（纯黑，圆角贴合）
2. 鼠标移到刘海上 → 黑色面板用弹簧动画向下展开，显示"音乐区 | 文件架"占位
3. 鼠标移出面板 → 自动收起，动画流畅不被裁剪
4. 全屏应用下重复 2-3 仍正常

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: 悬停展开/收起状态接线与弹簧动画"
```

---

### Task 6: NowPlaying 数据模型与解析器（TDD）

**Files:**
- Create: `Sources/DynamicIsland/Music/NowPlayingInfo.swift`
- Create: `Sources/DynamicIsland/Music/NowPlayingParser.swift`
- Create: `Sources/DynamicIsland/Music/NowPlayingProvider.swift`
- Test: `Tests/DynamicIslandTests/NowPlayingParserTests.swift`

AppleScript 返回约定（6 行，`\n` 分隔）：`标题\n歌手\n位置秒\n时长秒\n播放状态\n封面URL（可空）`。
注意：AppleScript 在部分地区设置下数字用**逗号小数点**（如 `12,34`），解析必须兼容。

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import DynamicIsland

final class NowPlayingParserTests: XCTestCase {
    func testParsesSpotifyPlayingOutput() {
        let raw = "Bohemian Rhapsody\nQueen\n123.45\n354.0\nplaying\nhttps://i.scdn.co/image/abc"
        let info = NowPlayingParser.parse(raw, source: .spotify)
        XCTAssertEqual(info, NowPlayingInfo(
            source: .spotify, title: "Bohemian Rhapsody", artist: "Queen",
            isPlaying: true, positionSec: 123.45, durationSec: 354.0,
            artworkURL: URL(string: "https://i.scdn.co/image/abc")))
    }

    func testParsesPausedState() {
        let raw = "Song\nArtist\n10\n200\npaused\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.isPlaying, false)
        XCTAssertNil(info?.artworkURL)
    }

    func testParsesCommaDecimalSeparator() {
        let raw = "Song\nArtist\n12,5\n200,0\nplaying\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.positionSec, 12.5)
        XCTAssertEqual(info?.durationSec, 200.0)
    }

    func testEmptyOutputReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("", source: .music))
    }

    func testMalformedOutputReturnsNil() {
        XCTAssertNil(NowPlayingParser.parse("only\nthree\nlines", source: .spotify))
        XCTAssertNil(NowPlayingParser.parse("t\na\nNaN??\n200\nplaying\n", source: .spotify))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter NowPlayingParserTests`
Expected: FAIL（`cannot find 'NowPlayingParser'`）。

- [ ] **Step 3: 实现三个文件**

`Sources/DynamicIsland/Music/NowPlayingInfo.swift`：

```swift
import Foundation

struct NowPlayingInfo: Equatable {
    enum Source: String, Equatable {
        case music
        case spotify
    }
    var source: Source
    var title: String
    var artist: String
    var isPlaying: Bool
    var positionSec: Double
    var durationSec: Double
    var artworkURL: URL?   // Spotify 提供；Music 封面走单独的数据查询
}
```

`Sources/DynamicIsland/Music/NowPlayingParser.swift`：

```swift
import Foundation

enum NowPlayingParser {
    /// 解析 AppleScript 输出。格式：标题\n歌手\n位置\n时长\n状态\n封面URL
    static func parse(_ raw: String, source: NowPlayingInfo.Source) -> NowPlayingInfo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lines = raw.components(separatedBy: "\n")
        guard lines.count >= 5 else { return nil }
        guard let position = parseNumber(lines[2]),
              let duration = parseNumber(lines[3]) else { return nil }
        let state = lines[4].trimmingCharacters(in: .whitespaces).lowercased()
        let artworkRaw = lines.count >= 6 ? lines[5].trimmingCharacters(in: .whitespaces) : ""
        return NowPlayingInfo(
            source: source,
            title: lines[0],
            artist: lines[1],
            isPlaying: state == "playing",
            positionSec: position,
            durationSec: duration,
            artworkURL: artworkRaw.isEmpty ? nil : URL(string: artworkRaw))
    }

    /// AppleScript 数字可能用逗号作小数点（地区设置），统一替换后解析
    private static func parseNumber(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
```

`Sources/DynamicIsland/Music/NowPlayingProvider.swift`：

```swift
import AppKit

/// 正在播放数据源协议（spec 留的扩展点：后续可加系统级实现而不动 UI）。
/// 回调均在主线程触发。
protocol NowPlayingProvider: AnyObject {
    var onUpdate: ((NowPlayingInfo?) -> Void)? { get set }
    var onArtwork: ((NSImage?) -> Void)? { get set }
    var onPermissionDenied: (() -> Void)? { get set }
    func start()
    func stop()
    func playPause()
    func nextTrack()
    func previousTrack()
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter NowPlayingParserTests`
Expected: PASS，5 个测试全绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/DynamicIsland/Music Tests/DynamicIslandTests/NowPlayingParserTests.swift
git commit -m "feat: NowPlaying 模型、解析器与 Provider 协议"
```

---

### Task 7: AppleScript 音乐数据源

**Files:**
- Create: `Sources/DynamicIsland/Music/AppleScriptRunner.swift`
- Create: `Sources/DynamicIsland/Music/AppleScriptMusicProvider.swift`
- Create: `Sources/DynamicIsland/Music/MusicViewModel.swift`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`

- [ ] **Step 1: 创建 `Sources/DynamicIsland/Music/AppleScriptRunner.swift`**

```swift
import Foundation

enum ScriptError: Error, Equatable {
    case compileFailed
    case permissionDenied      // TCC 自动化授权被拒（错误码 -1743）
    case execution(String)
}

protocol ScriptRunning {
    func run(_ source: String) throws -> NSAppleEventDescriptor
}

/// NSAppleScript 非线程安全：调用方保证始终在同一队列上执行（Provider 用专用串行队列）。
final class AppleScriptRunner: ScriptRunning {
    func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw ScriptError.compileFailed
        }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if let errorDict {
            let code = errorDict[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw ScriptError.permissionDenied }
            throw ScriptError.execution("\(errorDict)")
        }
        return result
    }
}
```

- [ ] **Step 2: 创建 `Sources/DynamicIsland/Music/AppleScriptMusicProvider.swift`**

```swift
import AppKit

/// 每 2 秒轮询 Spotify / Apple Music。
/// 两者同时播放时优先 Spotify（spec 决策：Music 常驻后台易误判）。
/// 重要：tell application 会启动未运行的应用，必须先用 NSRunningApplication 检查。
final class AppleScriptMusicProvider: NowPlayingProvider {
    var onUpdate: ((NowPlayingInfo?) -> Void)?
    var onArtwork: ((NSImage?) -> Void)?
    var onPermissionDenied: (() -> Void)?

    private let runner: ScriptRunning
    private let queue = DispatchQueue(label: "io.github.ljk20041215.lindongdao.music")
    private var timer: DispatchSourceTimer?
    private var lastArtworkKey: String?
    private var permissionReported = false

    private static let spotifyBundleID = "com.spotify.client"
    private static let musicBundleID = "com.apple.Music"

    init(runner: ScriptRunning = AppleScriptRunner()) {
        self.runner = runner
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 2.0)
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - 控制

    func playPause() { control("playpause") }
    func nextTrack() { control("next track") }
    func previousTrack() { control("previous track") }

    private func control(_ command: String) {
        queue.async { [weak self] in
            guard let self, let app = self.activePlayerApp() else { return }
            _ = try? self.runner.run("tell application \"\(app)\" to \(command)")
            self.poll()   // 立即刷新，不等下个轮询周期
        }
    }

    // MARK: - 轮询

    private func poll() {
        guard let app = activePlayerApp() else {
            publish(nil)
            return
        }
        do {
            let script = app == "Spotify" ? Self.spotifyScript : Self.musicScript
            let raw = try runner.run(script).stringValue ?? ""
            let source: NowPlayingInfo.Source = app == "Spotify" ? .spotify : .music
            guard let info = NowPlayingParser.parse(raw, source: source) else {
                publish(nil)
                return
            }
            publish(info)
            fetchArtworkIfNeeded(for: info)
        } catch ScriptError.permissionDenied {
            if !permissionReported {
                permissionReported = true
                DispatchQueue.main.async { [weak self] in self?.onPermissionDenied?() }
            }
            publish(nil)
        } catch {
            publish(nil)
        }
    }

    /// 优先 Spotify；仅检测在运行的应用，绝不通过 AppleScript 启动它们
    private func activePlayerApp() -> String? {
        if isRunning(Self.spotifyBundleID) { return "Spotify" }
        if isRunning(Self.musicBundleID) { return "Music" }
        return nil
    }

    private func isRunning(_ bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    private func publish(_ info: NowPlayingInfo?) {
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(info) }
    }

    // MARK: - 封面

    private func fetchArtworkIfNeeded(for info: NowPlayingInfo) {
        let key = "\(info.source.rawValue)|\(info.title)|\(info.artist)"
        guard key != lastArtworkKey else { return }
        lastArtworkKey = key

        if let url = info.artworkURL {
            // Spotify：封面是 https URL
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                let image = data.flatMap(NSImage.init(data:))
                DispatchQueue.main.async { self?.onArtwork?(image) }
            }.resume()
        } else if info.source == .music {
            // Apple Music：封面走 artwork data 查询，失败则降级为 nil（UI 显示占位图标）
            let image = (try? runner.run(Self.musicArtworkScript))
                .flatMap { $0.data.isEmpty ? nil : NSImage(data: $0.data) }
            DispatchQueue.main.async { [weak self] in self?.onArtwork?(image) }
        } else {
            DispatchQueue.main.async { [weak self] in self?.onArtwork?(nil) }
        }
    }

    // MARK: - 脚本

    /// Spotify duration 单位是毫秒，这里换算成秒
    static let spotifyScript = """
    try
        tell application "Spotify"
            if player state is stopped then return ""
            set t to current track
            return name of t & "\\n" & artist of t & "\\n" & (player position as text) & "\\n" & ((duration of t) / 1000 as text) & "\\n" & (player state as text) & "\\n" & artwork url of t
        end tell
    on error
        return ""
    end try
    """

    static let musicScript = """
    try
        tell application "Music"
            if player state is stopped then return ""
            set t to current track
            return name of t & "\\n" & artist of t & "\\n" & (player position as text) & "\\n" & (duration of t as text) & "\\n" & (player state as text) & "\\n"
        end tell
    on error
        return ""
    end try
    """

    static let musicArtworkScript = """
    try
        tell application "Music"
            return data of artwork 1 of current track
        end tell
    on error
        return ""
    end try
    """
}
```

- [ ] **Step 3: 创建 `Sources/DynamicIsland/Music/MusicViewModel.swift`**

```swift
import AppKit

final class MusicViewModel: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var needsAutomationPermission = false

    private let provider: NowPlayingProvider

    init(provider: NowPlayingProvider) {
        self.provider = provider
        provider.onUpdate = { [weak self] info in
            self?.info = info
            if info == nil { self?.artwork = nil }
        }
        provider.onArtwork = { [weak self] image in self?.artwork = image }
        provider.onPermissionDenied = { [weak self] in
            self?.needsAutomationPermission = true
        }
    }

    func start() { provider.start() }
    func playPause() { provider.playPause() }
    func nextTrack() { provider.nextTrack() }
    func previousTrack() { provider.previousTrack() }
}
```

- [ ] **Step 4: 修改 `AppDelegate.swift`：创建 MusicViewModel 并加临时日志**

整个文件替换为：

```swift
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
```

- [ ] **Step 5: 构建 + 全量测试**

Run: `swift build && swift test`
Expected: Build complete，全部测试通过。

- [ ] **Step 6: 【人工】运行验证**

前置：打开 Apple Music 或 Spotify 播放任意歌曲。
Run: `swift run lindongdao`
Expected:
1. 首次会弹"'Terminal' 想要控制 'Music'"授权框 → 点允许
2. 终端每 2 秒输出 `正在播放: <歌名> - <歌手> (playing)`
3. 暂停音乐 → 输出变为 `(paused)`；退出音乐应用 → 输出 `未在播放`
4. 若拒绝授权 → 输出 `未在播放` 且不崩溃、不重复弹框

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: AppleScript 音乐数据源（Spotify/Music 轮询与控制）"
```

---

### Task 8: 音乐界面（收起态翼 + 展开态面板）

**Files:**
- Create: `Sources/DynamicIsland/Island/WaveformView.swift`
- Create: `Sources/DynamicIsland/Music/MusicPanelView.swift`
- Modify: `Sources/DynamicIsland/Island/CollapsedIslandView.swift`
- Modify: `Sources/DynamicIsland/Island/ExpandedPanelView.swift`
- Modify: `Sources/DynamicIsland/Island/IslandRootView.swift`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`（传入 musicVM、删临时日志）

- [ ] **Step 1: 创建 `Sources/DynamicIsland/Island/WaveformView.swift`**

```swift
import SwiftUI

/// 收起态右翼的音频波形：4 根跳动的竖条
struct WaveformView: View {
    let isPlaying: Bool
    @State private var animating = false

    private let baseHeights: [CGFloat] = [8, 16, 11, 14]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.green)
                    .frame(width: 3,
                           height: animating ? baseHeights[i] : 5)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.12)
                            : .default,
                        value: animating)
            }
        }
        .frame(height: 18)
        .onAppear { animating = isPlaying }
        .onChange(of: isPlaying) { _, playing in animating = playing }
    }
}
```

- [ ] **Step 2: 创建 `Sources/DynamicIsland/Music/MusicPanelView.swift`**

```swift
import SwiftUI

/// 展开面板左侧的音乐区
struct MusicPanelView: View {
    @ObservedObject var musicVM: MusicViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if musicVM.needsAutomationPermission {
                permissionHint
            } else if let info = musicVM.info {
                playingContent(info)
            } else {
                notPlaying
            }
        }
        .frame(width: 240, alignment: .leading)
    }

    private func playingContent(_ info: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(info.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            ProgressView(value: min(info.positionSec, info.durationSec),
                         total: max(info.durationSec, 1))
                .tint(.white)
            HStack(spacing: 28) {
                controlButton("backward.fill") { musicVM.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill") { musicVM.playPause() }
                controlButton("forward.fill") { musicVM.nextTrack() }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var artworkView: some View {
        Group {
            if let artwork = musicVM.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.08))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var notPlaying: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundStyle(.gray)
            Text("未在播放")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundStyle(.yellow)
            Text("需要自动化权限才能读取播放信息")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Text("系统设置 → 隐私与安全性 → 自动化")
                .font(.system(size: 10))
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 3: 替换 `CollapsedIslandView.swift`（加音乐翼）**

整个文件替换为：

```swift
import SwiftUI

/// 收起态：黑色胶囊包住刘海。播放音乐时左翼露出迷你封面、右翼露出波形；
/// 无音乐时翼宽为 0，岛与刘海完全一致。
struct CollapsedIslandView: View {
    let notchSize: CGSize
    @ObservedObject var musicVM: MusicViewModel

    private var hasMusic: Bool { musicVM.info != nil }

    var body: some View {
        HStack(spacing: 0) {
            leftChip
            Color.black.frame(width: notchSize.width, height: notchSize.height)
            rightChip
        }
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }

    private var leftChip: some View {
        Group {
            if hasMusic {
                HStack {
                    Spacer()
                    artworkThumb
                }
                .padding(.trailing, 6)
                .frame(width: IslandLayout.chipWidth, height: notchSize.height)
            }
        }
    }

    private var rightChip: some View {
        Group {
            if hasMusic {
                HStack {
                    WaveformView(isPlaying: musicVM.info?.isPlaying == true)
                    Spacer()
                }
                .padding(.leading, 6)
                .frame(width: IslandLayout.chipWidth, height: notchSize.height)
            }
        }
    }

    private var artworkThumb: some View {
        Group {
            if let artwork = musicVM.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 4: 修改 `ExpandedPanelView.swift`（接入音乐区，文件架仍占位）**

整个文件替换为：

```swift
import SwiftUI

struct ExpandedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel

    var body: some View {
        HStack(spacing: 16) {
            MusicPanelView(musicVM: musicVM)
            Divider().overlay(.gray.opacity(0.4))
            Text("文件架").foregroundStyle(.secondary)   // Task 10 替换
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }
}
```

- [ ] **Step 5: 修改 `IslandRootView.swift` 传递 musicVM**

整个文件替换为：

```swift
import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize, musicVM: musicVM)
            case .expanded, .dropTarget:
                ExpandedPanelView(musicVM: musicVM)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
    }
}
```

- [ ] **Step 6: 修改 `AppDelegate.swift`：传 musicVM、删除临时日志**

把 `controller.show(...)` 一行改为：

```swift
        controller.show(content: IslandRootView(
            viewModel: islandVM,
            musicVM: musicVM,
            notchSize: geometry.notchRect.size))
```

删除 `logNowPlaying()` 调用与整个 `logNowPlaying()` 方法。

- [ ] **Step 7: 构建 + 全量测试**

Run: `swift build && swift test`
Expected: Build complete，全部测试通过。

- [ ] **Step 8: 【人工】运行验证**

前置：播放音乐（先后试 Music 和 Spotify）。
Run: `swift run lindongdao`
Expected:
1. 收起态：刘海左侧露出迷你封面、右侧绿色波形跳动；暂停时波形停止
2. 无音乐时：岛与刘海融为一体，无翼
3. 悬停展开：左侧大封面 + 歌名/歌手 + 进度条 + 三个控制按钮
4. 点播放/暂停/上一首/下一首 → 音乐应用响应，按钮图标随状态切换
5. 进度条随播放每 2 秒前进
6. Spotify 与 Music 同时打开时显示 Spotify 的内容

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: 音乐界面（收起态封面/波形翼 + 展开态播放控制）"
```

---

### Task 9: ShelfStore 文件架数据层（TDD）

**Files:**
- Create: `Sources/DynamicIsland/Shelf/ShelfItem.swift`
- Create: `Sources/DynamicIsland/Shelf/ShelfStore.swift`
- Test: `Tests/DynamicIslandTests/ShelfStoreTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import XCTest
@testable import DynamicIsland

final class ShelfStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lindongdao-tests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeStore(fileExists: @escaping (URL) -> Bool = { _ in true }) -> ShelfStore {
        ShelfStore(storeURL: tempDir.appendingPathComponent("shelf.json"),
                   fileExists: fileExists)
    }

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testAddAndRemove() {
        let store = makeStore()
        store.add(urls: [url("a.txt"), url("b.txt")])
        XCTAssertEqual(store.items.map(\.url), [url("a.txt"), url("b.txt")])
        store.remove(store.items[0].id)
        XCTAssertEqual(store.items.map(\.url), [url("b.txt")])
    }

    func testRejectsBeyondMaxItems() {
        let store = makeStore()
        let urls = (0..<12).map { url("f\($0).txt") }
        let rejected = store.add(urls: urls)
        XCTAssertEqual(store.items.count, ShelfStore.maxItems)
        XCTAssertEqual(rejected, [url("f10.txt"), url("f11.txt")])
    }

    func testDeduplicatesSameURL() {
        let store = makeStore()
        store.add(urls: [url("a.txt")])
        let rejected = store.add(urls: [url("a.txt")])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(rejected.isEmpty)   // 重复不算拒绝，静默忽略
    }

    func testClear() {
        let store = makeStore()
        store.add(urls: [url("a.txt"), url("b.txt")])
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistsAcrossInstances() {
        let store1 = makeStore()
        store1.add(urls: [url("a.txt")])
        let store2 = makeStore()
        XCTAssertEqual(store2.items.map(\.url), [url("a.txt")])
    }

    func testMissingFileDetection() {
        let store = makeStore(fileExists: { $0.lastPathComponent != "gone.txt" })
        store.add(urls: [url("here.txt"), url("gone.txt")])
        XCTAssertFalse(store.isMissing(store.items[0]))
        XCTAssertTrue(store.isMissing(store.items[1]))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter ShelfStoreTests`
Expected: FAIL（`cannot find 'ShelfStore'`）。

- [ ] **Step 3: 实现两个文件**

`Sources/DynamicIsland/Shelf/ShelfItem.swift`：

```swift
import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let addedAt: Date
}
```

`Sources/DynamicIsland/Shelf/ShelfStore.swift`：

```swift
import Foundation

/// 文件架数据层：保存文件引用（不复制文件本体），JSON 持久化。
/// storeURL 与 fileExists 注入以便测试。
final class ShelfStore: ObservableObject {
    static let maxItems = 10

    @Published private(set) var items: [ShelfItem] = []

    private let storeURL: URL
    private let fileExists: (URL) -> Bool

    init(storeURL: URL = ShelfStore.defaultStoreURL,
         fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.storeURL = storeURL
        self.fileExists = fileExists
        load()
    }

    static var defaultStoreURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lindongdao/shelf.json")
    }

    /// 返回因超出上限被拒绝的 URL（重复项静默忽略，不算拒绝）
    @discardableResult
    func add(urls: [URL]) -> [URL] {
        var rejected: [URL] = []
        for url in urls {
            if items.contains(where: { $0.url == url }) { continue }
            if items.count >= Self.maxItems {
                rejected.append(url)
                continue
            }
            items.append(ShelfItem(id: UUID(), url: url, addedAt: Date()))
        }
        save()
        return rejected
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    /// 源文件被删除/移动 → UI 灰显（spec 错误处理表）
    func isMissing(_ item: ShelfItem) -> Bool {
        !fileExists(item.url)
    }

    // MARK: - 持久化（失败静默：文件架丢失不应让应用崩溃）

    private func save() {
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storeURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = decoded
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter ShelfStoreTests`
Expected: PASS，6 个测试全绿。

- [ ] **Step 5: Commit**

```bash
git add Sources/DynamicIsland/Shelf Tests/DynamicIslandTests/ShelfStoreTests.swift
git commit -m "feat: 文件架数据层（上限/去重/持久化/失效检测）"
```

---

### Task 10: 文件架界面与拖放

**Files:**
- Create: `Sources/DynamicIsland/Shelf/ThumbnailLoader.swift`
- Create: `Sources/DynamicIsland/Shelf/ShelfPanelView.swift`
- Create: `Sources/DynamicIsland/Island/ShakeEffect.swift`
- Modify: `Sources/DynamicIsland/Island/ExpandedPanelView.swift`
- Modify: `Sources/DynamicIsland/Island/IslandRootView.swift`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`

- [ ] **Step 1: 创建 `Sources/DynamicIsland/Shelf/ThumbnailLoader.swift`**

```swift
import AppKit
import QuickLookThumbnailing

/// 为单个文件异步生成缩略图；失败降级为系统文件图标
final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    func load(url: URL, side: CGFloat = 44) {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: 2,
            representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            DispatchQueue.main.async {
                self?.image = rep?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }
}
```

- [ ] **Step 2: 创建 `Sources/DynamicIsland/Island/ShakeEffect.swift`**

```swift
import SwiftUI

/// 文件架满时的水平抖动（spec 错误处理表）。trigger 整数 +1 触发一次。
struct ShakeEffect: GeometryEffect {
    var trigger: CGFloat

    var animatableData: CGFloat {
        get { trigger }
        set { trigger = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 8 * sin(trigger * .pi * 4), y: 0))
    }
}
```

- [ ] **Step 3: 创建 `Sources/DynamicIsland/Shelf/ShelfPanelView.swift`**

```swift
import SwiftUI
import UniformTypeIdentifiers

/// 展开面板右侧的文件架
struct ShelfPanelView: View {
    @ObservedObject var store: ShelfStore
    let isDropTarget: Bool

    private let columns = Array(repeating: GridItem(.fixed(56), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if store.items.isEmpty {
                emptyHint
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(store.items) { item in
                        ShelfItemView(item: item,
                                      isMissing: store.isMissing(item),
                                      onRemove: { store.remove(item.id) })
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        Text("放在这里")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.blue)
                    }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("文件架 \(store.items.count)/\(ShelfStore.maxItems)")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            Spacer()
            if !store.items.isEmpty {
                Button("清空") { store.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22))
                .foregroundStyle(.gray)
            Text("拖文件到这里暂存")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 单个文件项：缩略图 + 文件名；hover 显示 × 移除；失效灰显；可拖出
struct ShelfItemView: View {
    let item: ShelfItem
    let isMissing: Bool
    let onRemove: () -> Void

    @StateObject private var thumbnail = ThumbnailLoader()
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                }
            }
            Text(item.url.lastPathComponent)
                .font(.system(size: 9))
                .foregroundStyle(isMissing ? .gray.opacity(0.5) : .gray)
                .lineLimit(1)
                .frame(width: 56)
        }
        .opacity(isMissing ? 0.4 : 1)
        .onHover { hovering = $0 }
        .onAppear { thumbnail.load(url: item.url) }
        // 拖出到 Finder / 任意应用。失效文件禁止拖出。
        .onDrag {
            isMissing ? NSItemProvider() : (NSItemProvider(contentsOf: item.url) ?? NSItemProvider())
        }
    }

    private var thumbnailImage: some View {
        Group {
            if let image = thumbnail.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 44, height: 44)
    }
}
```

- [ ] **Step 4: 修改 `ExpandedPanelView.swift`（接入文件架与抖动）**

整个文件替换为：

```swift
import SwiftUI

struct ExpandedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    let isDropTarget: Bool
    let shakeTrigger: Int

    var body: some View {
        HStack(spacing: 16) {
            MusicPanelView(musicVM: musicVM)
            Divider().overlay(.gray.opacity(0.4))
            ShelfPanelView(store: shelf, isDropTarget: isDropTarget)
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .modifier(ShakeEffect(trigger: CGFloat(shakeTrigger)))
        .animation(.linear(duration: 0.4), value: shakeTrigger)
    }
}
```

- [ ] **Step 5: 修改 `IslandRootView.swift`（根级 onDrop：拖拽悬停展开 + 投放入架）**

整个文件替换为：

```swift
import SwiftUI
import UniformTypeIdentifiers

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    let notchSize: CGSize

    @State private var dropTargeted = false
    @State private var shakeTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize, musicVM: musicVM)
            case .expanded, .dropTarget:
                ExpandedPanelView(musicVM: musicVM,
                                  shelf: shelf,
                                  isDropTarget: viewModel.state == .dropTarget,
                                  shakeTrigger: shakeTrigger)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        // 文件拖到岛的任何位置：悬停 → dropTarget 态展开；松手 → 入架
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            Self.loadFileURLs(from: providers) { urls in
                guard !urls.isEmpty else { return }
                let rejected = shelf.add(urls: urls)
                if !rejected.isEmpty { shakeTrigger += 1 }   // 满架抖动
                viewModel.send(.dropCompleted)
            }
            return true
        }
        .onChange(of: dropTargeted) { _, targeted in
            viewModel.setDragTargeted(targeted)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
    }

    /// NSItemProvider 异步取出文件 URL；忽略非文件内容（spec：只接受文件）
    static func loadFileURLs(from providers: [NSItemProvider],
                             completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) { completion(urls) }
    }
}
```

- [ ] **Step 6: 修改 `AppDelegate.swift`（创建 ShelfStore 并传入）**

在 `private let musicVM = ...` 下面加一行：

```swift
    private let shelf = ShelfStore()
```

把 `controller.show(...)` 改为：

```swift
        controller.show(content: IslandRootView(
            viewModel: islandVM,
            musicVM: musicVM,
            shelf: shelf,
            notchSize: geometry.notchRect.size))
```

- [ ] **Step 7: 构建 + 全量测试**

Run: `swift build && swift test`
Expected: Build complete，全部测试通过。

- [ ] **Step 8: 【人工】运行验证**

Run: `swift run lindongdao`
Expected:
1. 从 Finder/桌面拖一个文件到刘海 → 岛自动展开、文件架区域蓝色虚线高亮"放在这里"
2. 松手 → 文件出现在架上（缩略图 + 文件名），岛保持展开
3. 把架上文件拖出到桌面/Finder → 文件被复制过去，架上仍保留
4. hover 文件项 → 出现 × 按钮，点击移除；"清空"按钮清空全部
5. 重启应用（Ctrl+C 后重新 `swift run lindongdao`）→ 架上内容还在
6. 在 Finder 删除某个架上文件的源文件 → 该项灰显，不可拖出，可移除
7. 添加到 10 个后再拖入 → 面板左右抖动，文件不入架
8. 拖入拖到一半移出岛 → 岛收起，不闪烁

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: 文件中转站（拖入/拖出/缩略图/满架抖动/失效灰显）"
```

---

### Task 11: 打包脚本、退出入口与 README

**Files:**
- Create: `scripts/Info.plist`
- Create: `scripts/make_app.sh`
- Create: `README.md`
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`（加状态栏退出菜单）

- [ ] **Step 1: 给 AppDelegate 加状态栏退出菜单**

应用无 Dock 图标、岛本身没有关闭按钮，打包后用户需要退出入口。
在 `AppDelegate` 中加属性：

```swift
    private var statusItem: NSStatusItem?
```

在 `applicationDidFinishLaunching` 末尾加：

```swift
        setupStatusItem()
```

加方法：

```swift
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
```

- [ ] **Step 2: 创建 `scripts/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>io.github.ljk20041215.lindongdao</string>
    <key>CFBundleName</key>
    <string>lindongdao</string>
    <key>CFBundleExecutable</key>
    <string>lindongdao</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>lindongdao 需要控制 Music/Spotify 来显示和切换正在播放的音乐。</string>
</dict>
</plist>
```

- [ ] **Step 3: 创建 `scripts/make_app.sh`**

```bash
#!/bin/bash
# 把 SwiftPM 产物打包成可双击运行的 .app（ad-hoc 签名，仅本机使用）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/lindongdao.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/lindongdao "$APP/Contents/MacOS/lindongdao"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "✅ 已生成 $APP（可拖到 /Applications）"
```

然后：`chmod +x scripts/make_app.sh`

- [ ] **Step 4: 创建 `README.md`**

```markdown
# lindongdao 灵动岛

macOS 灵动岛：悬停刘海展开，左侧音乐播放（Apple Music / Spotify），右侧文件中转站。

## 运行（开发）

```bash
swift run lindongdao    # Ctrl+C 退出
```

## 打包

```bash
./scripts/make_app.sh   # 生成 build/lindongdao.app，可拖到 /Applications
```

## 使用

- **悬停刘海** → 展开面板；移开 → 收起
- **音乐**：播放 Music 或 Spotify 时刘海两侧显示封面与波形，展开后可控制播放
- **文件架**：拖文件到刘海暂存（最多 10 个），从架上拖出到任意位置使用；× 移除，重启不丢失
- **退出**：菜单栏胶囊图标 → 退出

## 权限

首次控制音乐时系统会请求"自动化"权限，请允许。误拒后到
系统设置 → 隐私与安全性 → 自动化 中重新开启。

## 测试

```bash
swift test
```
```

- [ ] **Step 5: 构建 + 全量测试 + 打包**

Run: `swift build && swift test && ./scripts/make_app.sh`
Expected: 测试全绿；输出 `✅ 已生成 build/lindongdao.app`。

- [ ] **Step 6: 【人工】最终验收清单（对照 spec 测试策略）**

双击 `build/lindongdao.app` 运行（注意：打包后的应用是独立 TCC 主体，会重新弹一次自动化授权），逐项确认：

1. [ ] 岛与刘海融为一体；菜单栏出现胶囊图标，"退出"可退出应用
2. [ ] hover 展开/移开收起动画流畅
3. [ ] 全屏应用下岛可见且可交互
4. [ ] Music 播放：封面/歌名/进度/控制正常
5. [ ] Spotify 播放：封面/歌名/进度/控制正常；与 Music 同开时优先 Spotify
6. [ ] 从 Finder 拖入文件 → 高亮、入架；拖出到 Finder 与第三方应用（如微信）正常
7. [ ] 架满 10 个抖动拒收；删除源文件后灰显；重启后文件架保留
8. [ ] 拒绝自动化授权 → 显示引导提示，不崩溃

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: 打包脚本、状态栏退出菜单与 README"
```

---

## 验收完成后

全部任务完成且最终验收清单通过后，使用 superpowers:finishing-a-development-branch 技能收尾。
遗留扩展点（已在 spec 标注为第一版不做）：设置界面、开机自启、外接显示器、系统级 now playing、通知/日历。
