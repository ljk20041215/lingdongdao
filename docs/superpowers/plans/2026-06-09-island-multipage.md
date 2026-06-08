# 灵动岛多页 + 左右滑切换 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把展开面板改成横向多页（音乐 / 文件中转站），可两指滑或点页点切换。

**Architecture:** 一个常驻页模型（IslandPagesModel）+ 纯滑动判定（PageSwipe）+ AppKit 滚动监听（SwipeMonitor）驱动；分页容器 PagedPanelView 横向排列各页、底部画可点页点、按页索引 offset 滑动。文件中转站从下线状态恢复为整页。

**Tech Stack:** Swift / SwiftUI / AppKit（NSEvent 本地监听）/ SwiftPM / XCTest（纯逻辑 TDD，手势与布局人工验收）。

**全局须知：** 工作目录 `~/Desktop/lindongdao`。构建 `swift build`；测试 `swift test`；打包 `./scripts/make_app.sh`。`【人工】` 需运行 app 确认。当前展开面板由 `ExpandedPanelView`（音乐+设备行）+ `FeatureFlags.shelfEnabled=false` 构成；本计划用 `PagedPanelView` 取代，并删除 `FeatureFlags.swift`、`ExpandedPanelView.swift`。

---

## 文件结构

- 新建 `Sources/DynamicIsland/Island/IslandPage.swift` —— 页枚举
- 新建 `Sources/DynamicIsland/Island/IslandPagesModel.swift` —— 当前页（go/advance 钳制）
- 新建 `Sources/DynamicIsland/Island/PageSwipe.swift` —— 纯滑动判定
- 新建 `Sources/DynamicIsland/Island/SwipeMonitor.swift` —— 两指水平滚动监听（AppKit）
- 新建 `Sources/DynamicIsland/Island/PageDotsView.swift` —— 可点页点
- 新建 `Sources/DynamicIsland/Island/PagedPanelView.swift` —— 分页容器
- 改 `Sources/DynamicIsland/Shelf/ShelfPanelView.swift` —— 整页化（4 列 + 横向内边距）
- 改 `Sources/DynamicIsland/Island/IslandRootView.swift` —— 用 PagedPanelView、恢复拖放入文件页、注入 pages
- 改 `Sources/DynamicIsland/App/AppDelegate.swift` —— 创建注入 IslandPagesModel
- 改 `Sources/DynamicIsland/Island/IslandLayout.swift` —— expandedSize 固定 340×300
- 改 `README.md` —— 去掉文件架下线说明
- 删 `Sources/DynamicIsland/Support/FeatureFlags.swift`、`Sources/DynamicIsland/Island/ExpandedPanelView.swift`
- 新建测试 `IslandPagesModelTests.swift`、`PageSwipeTests.swift`

---

### Task 1: 页模型 IslandPage + IslandPagesModel

**Files:**
- Create: `Sources/DynamicIsland/Island/IslandPage.swift`
- Create: `Sources/DynamicIsland/Island/IslandPagesModel.swift`
- Test: `Tests/DynamicIslandTests/IslandPagesModelTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/DynamicIslandTests/IslandPagesModelTests.swift`:
```swift
import XCTest
@testable import DynamicIsland

final class IslandPagesModelTests: XCTestCase {
    func testDefaultIsMusic() {
        XCTAssertEqual(IslandPagesModel().current, .music)
    }
    func testGoSetsCurrent() {
        let m = IslandPagesModel()
        m.go(to: .shelf)
        XCTAssertEqual(m.current, .shelf)
    }
    func testAdvanceMovesOnePage() {
        let m = IslandPagesModel()
        m.advance(by: 1)
        XCTAssertEqual(m.current, .shelf)
    }
    func testAdvanceClampsAtStart() {
        let m = IslandPagesModel()           // .music = 第 0 页
        m.advance(by: -1)
        XCTAssertEqual(m.current, .music)    // 不回绕
    }
    func testAdvanceClampsAtEnd() {
        let m = IslandPagesModel()
        m.go(to: .shelf)                     // 末页
        m.advance(by: 1)
        XCTAssertEqual(m.current, .shelf)    // 不回绕
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter IslandPagesModelTests`
Expected: 编译失败（IslandPage / IslandPagesModel 未定义）。

- [ ] **Step 3: 实现**

`Sources/DynamicIsland/Island/IslandPage.swift`:
```swift
/// 展开面板的页。rawValue 即页序；CaseIterable 给顺序与数量（加页只需加 case）。
enum IslandPage: Int, CaseIterable {
    case music
    case shelf
}
```

`Sources/DynamicIsland/Island/IslandPagesModel.swift`:
```swift
import Foundation

/// 当前展开页。常驻（由 AppDelegate 持有），收起再展开记住上次页；不跨重启。
final class IslandPagesModel: ObservableObject {
    @Published private(set) var current: IslandPage = .music

    func go(to page: IslandPage) { current = page }

    /// 相对移动并钳制到首末页（不回绕）
    func advance(by delta: Int) {
        let clamped = max(0, min(IslandPage.allCases.count - 1, current.rawValue + delta))
        if let page = IslandPage(rawValue: clamped) { current = page }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter IslandPagesModelTests`
Expected: PASS（5 个）。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Island/IslandPage.swift Sources/DynamicIsland/Island/IslandPagesModel.swift Tests/DynamicIslandTests/IslandPagesModelTests.swift
git commit -m "feat: 灵动岛页模型（IslandPage + 当前页钳制）"
```

---

### Task 2: 纯滑动判定 PageSwipe

**Files:**
- Create: `Sources/DynamicIsland/Island/PageSwipe.swift`
- Test: `Tests/DynamicIslandTests/PageSwipeTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/DynamicIslandTests/PageSwipeTests.swift`:
```swift
import XCTest
@testable import DynamicIsland

final class PageSwipeTests: XCTestCase {
    // 约定（自然滚动）：手指左滑累计 dx 为负 → 下一页(+1)；右滑为正 → 上一页(-1)
    func testSwipeLeftGoesNext() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -50, threshold: 40), 1)
    }
    func testSwipeRightGoesPrev() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 50, threshold: 40), -1)
    }
    func testBelowThresholdNoChange() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 20, threshold: 40), 0)
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -20, threshold: 40), 0)
    }
    func testAtThresholdTriggers() {
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: -40, threshold: 40), 1)
        XCTAssertEqual(PageSwipe.pageDelta(accumulatedX: 40, threshold: 40), -1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter PageSwipeTests`
Expected: 编译失败（PageSwipe 未定义）。

- [ ] **Step 3: 实现**

`Sources/DynamicIsland/Island/PageSwipe.swift`:
```swift
/// 一次滑动手势的累计水平位移 → 翻页方向（+1 下一页 / -1 上一页 / 0 不翻）。
/// 约定（macOS 自然滚动）：手指左滑 scrollingDeltaX 累计为负 → 下一页。
/// 若实机方向相反（如关闭了自然滚动），把这两个判断的符号对调即可。
enum PageSwipe {
    static func pageDelta(accumulatedX: Double, threshold: Double) -> Int {
        if accumulatedX <= -threshold { return 1 }
        if accumulatedX >= threshold { return -1 }
        return 0
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter PageSwipeTests`
Expected: PASS（4 个）。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Island/PageSwipe.swift Tests/DynamicIslandTests/PageSwipeTests.swift
git commit -m "feat: 两指滑翻页的纯判定逻辑（阈值/方向/中性）"
```

---

### Task 3: 滚动监听 SwipeMonitor（AppKit）

**Files:**
- Create: `Sources/DynamicIsland/Island/SwipeMonitor.swift`

不单测（依赖真实滚动事件）；以编译 + 后续人工验收为准。用 `NSEvent` 本地监听，不拦截点击。

- [ ] **Step 1: 实现**

`Sources/DynamicIsland/Island/SwipeMonitor.swift`:
```swift
import AppKit

/// 监听本 app 的两指水平滚动（即在灵动岛面板上的滚动）：按手势累计 scrollingDeltaX，
/// 手势结束时用 PageSwipe 判定是否翻页。本地监听不拦截点击；忽略 momentum 惯性阶段。
final class SwipeMonitor {
    private var monitor: Any?
    private var accumulated: Double = 0
    private var tracking = false
    private let threshold: Double
    private let onPage: (Int) -> Void

    init(threshold: Double = 40, onPage: @escaping (Int) -> Void) {
        self.threshold = threshold
        self.onPage = onPage
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        accumulated = 0
        tracking = false
    }

    private func handle(_ event: NSEvent) {
        if event.phase.contains(.began) {
            tracking = true
            accumulated = 0
        } else if event.phase.contains(.changed) {
            if tracking { accumulated += Double(event.scrollingDeltaX) }
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            guard tracking else { return }
            tracking = false
            let delta = PageSwipe.pageDelta(accumulatedX: accumulated, threshold: threshold)
            accumulated = 0
            if delta != 0 { onPage(delta) }
        }
        // momentum（惯性）阶段 event.phase 为空 → 落到这里被忽略，避免一甩翻多页
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build`
Expected: 成功。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Island/SwipeMonitor.swift
git commit -m "feat: 两指水平滚动监听（本地监听，忽略惯性，不拦点击）"
```

---

### Task 4: 页点 PageDotsView

**Files:**
- Create: `Sources/DynamicIsland/Island/PageDotsView.swift`

- [ ] **Step 1: 实现**

`Sources/DynamicIsland/Island/PageDotsView.swift`:
```swift
import SwiftUI

/// 底部页点：当前页实心白，其余灰；点哪个回调哪个序号。
struct PageDotsView: View {
    let count: Int
    let current: Int
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.white : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(i) }
            }
        }
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build`
Expected: 成功。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Island/PageDotsView.swift
git commit -m "feat: 可点页点 PageDotsView"
```

---

### Task 5: ShelfPanelView 整页化（4 列 + 横向内边距）

**Files:**
- Modify: `Sources/DynamicIsland/Shelf/ShelfPanelView.swift`

整页宽（约 340）下 5 列放不下（5×56+40=320 > 内容区），改 4 列并加横向内边距。其余（header/空提示/拖出/失效/× 移除）不动。

- [ ] **Step 1: 改列数为 4**

把：
```swift
    private let columns = Array(repeating: GridItem(.fixed(56), spacing: 10), count: 5)
```
改为：
```swift
    private let columns = Array(repeating: GridItem(.fixed(56), spacing: 10), count: 4)
```

- [ ] **Step 2: 加横向内边距**

把 body 里最外层的：
```swift
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
```
改为（在 frame 后、overlay 前插入 `.padding(.horizontal, 16)`）：
```swift
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .overlay {
```

- [ ] **Step 3: 编译**

Run: `swift build`
Expected: 成功。

- [ ] **Step 4: 提交**

```bash
git add Sources/DynamicIsland/Shelf/ShelfPanelView.swift
git commit -m "feat: 文件架整页化（4 列 + 横向内边距）"
```

---

### Task 6: 分页容器 PagedPanelView

**Files:**
- Create: `Sources/DynamicIsland/Island/PagedPanelView.swift`

整合：横向 pager（音乐页 + 文件页）+ 底部页点 + 滑动监听 + 刘海上内边距 + 黑底圆角。

- [ ] **Step 1: 实现**

`Sources/DynamicIsland/Island/PagedPanelView.swift`:
```swift
import SwiftUI

/// 展开面板：横向多页（音乐 / 文件中转站）+ 底部页点 + 两指滑切换。
/// 每页等宽（= 面板宽），按当前页 offset 横向滑动；黑底铺满窗口、内容下移到刘海下方。
struct PagedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var audioVM: AudioOutputViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var pages: IslandPagesModel
    let isDropTarget: Bool
    let shakeTrigger: Int
    let notchHeight: CGFloat

    @State private var monitor: SwipeMonitor?

    private var pageWidth: CGFloat { IslandLayout.expandedSize.width }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                MusicPanelView(musicVM: musicVM, audioVM: audioVM)
                    .frame(width: pageWidth)
                ShelfPanelView(store: shelf, isDropTarget: isDropTarget)
                    .modifier(ShakeEffect(trigger: CGFloat(shakeTrigger)))
                    .animation(.linear(duration: 0.4), value: shakeTrigger)
                    .frame(width: pageWidth)
            }
            .frame(width: pageWidth, alignment: .leading)
            .offset(x: -CGFloat(pages.current.rawValue) * pageWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: pages.current)
            .clipped()
            .frame(maxHeight: .infinity)

            PageDotsView(count: IslandPage.allCases.count,
                         current: pages.current.rawValue) { idx in
                if let p = IslandPage(rawValue: idx) { pages.go(to: p) }
            }
        }
        .padding(.bottom, 10)
        .padding(.top, notchHeight + 4)
        .frame(maxWidth: .infinity)
        .frame(height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .onAppear {
            let m = SwipeMonitor(threshold: 40) { delta in pages.advance(by: delta) }
            m.start()
            monitor = m
        }
        .onDisappear {
            monitor?.stop()
            monitor = nil
        }
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build`
Expected: 成功（此时还没接进 IslandRootView，仅确认本视图能编过）。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Island/PagedPanelView.swift
git commit -m "feat: 分页容器 PagedPanelView（横向 pager + 页点 + 滑动）"
```

---

### Task 7: 接线 + 删旧 + 尺寸 + 拖放入文件页

**Files:**
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`
- Modify: `Sources/DynamicIsland/Island/IslandRootView.swift`
- Modify: `Sources/DynamicIsland/Island/IslandLayout.swift`
- Modify: `README.md`
- Delete: `Sources/DynamicIsland/Support/FeatureFlags.swift`
- Delete: `Sources/DynamicIsland/Island/ExpandedPanelView.swift`

- [ ] **Step 1: IslandLayout 固定尺寸（去 FeatureFlags 依赖）**

把 `expandedSize` 整段替换为：
```swift
    /// 展开面板尺寸（多页共用：横向滑动、每页等宽）
    static let expandedSize = CGSize(width: 340, height: 300)
```

- [ ] **Step 2: AppDelegate 创建并注入 pages**

在 `private let audioVM = ...` 后加：
```swift
    private let pages = IslandPagesModel()
```
把 `controller.show(content: IslandRootView( ... ))` 调用改为带上 `pages: pages,`（放在 `audioVM: audioVM,` 后）：
```swift
        controller.show(content: IslandRootView(
            viewModel: islandVM,
            musicVM: musicVM,
            shelf: shelf,
            audioVM: audioVM,
            pages: pages,
            notchSize: geometry.notchRect.size))
```

- [ ] **Step 3: IslandRootView 接入 PagedPanelView + 恢复拖放入文件页**

把 `IslandRootView` 的属性区（`@ObservedObject var audioVM` 后）加：
```swift
    @ObservedObject var pages: IslandPagesModel
```
把 `islandContent` 的展开分支整段替换为：
```swift
        case .expanded, .dropTarget:
            PagedPanelView(musicVM: musicVM,
                           audioVM: audioVM,
                           shelf: shelf,
                           pages: pages,
                           isDropTarget: viewModel.state == .dropTarget,
                           shakeTrigger: shakeTrigger,
                           notchHeight: notchSize.height)
```
把 body 里的 `.modifier(ShelfDropTarget(...))` 整段替换为（去掉 enabled，拖入即跳文件页 + 入架；拖拽悬停也跳文件页）：
```swift
        .modifier(ShelfDropTarget(
            targeted: $dropTargeted,
            onDrop: { providers in
                viewModel.send(.dropCompleted)
                pages.go(to: .shelf)
                Self.loadFileURLs(from: providers) { urls in
                    let rejected = shelf.add(urls: urls)
                    if !rejected.isEmpty { shakeTrigger += 1 }   // 满架抖动
                }
                return true
            },
            onTargetChange: { targeted in
                viewModel.setDragTargeted(targeted)
                if targeted { pages.go(to: .shelf) }
            }))
```
把文件末尾的 `private struct ShelfDropTarget` 整段替换为（去掉 enabled，始终接收拖放）：
```swift
/// 文件投放：始终接收，落点在岛任意位置即可（onDrop 在整窗外层，hover 在 islandContent）
private struct ShelfDropTarget: ViewModifier {
    @Binding var targeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    let onTargetChange: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.fileURL], isTargeted: $targeted, perform: onDrop)
            .onChange(of: targeted) { _, t in onTargetChange(t) }
    }
}
```

- [ ] **Step 4: 删除旧文件**

```bash
git rm Sources/DynamicIsland/Support/FeatureFlags.swift Sources/DynamicIsland/Island/ExpandedPanelView.swift
```

- [ ] **Step 5: README 去掉文件架下线说明**

把 README 顶部这段：
```markdown
> 当前版本专注音乐。文件中转站已实现但暂时下线（代码保留，把
> `FeatureFlags.shelfEnabled` 改回 `true` 即可恢复）。
```
删除（连同它上一行的空行）。并把第 3 行描述：
```markdown
macOS 灵动岛：悬停刘海展开音乐面板（Apple Music / Spotify）。
```
改为：
```markdown
macOS 灵动岛：悬停刘海展开，左右滑切换音乐页 / 文件中转站页。
```

- [ ] **Step 6: 编译 + 测试 + 打包**

Run: `swift build && swift test && ./scripts/make_app.sh`
Expected: 构建成功；测试全 PASS（数量 = 之前 45 + Task1 的 5 + Task2 的 4 = 54）；生成 `build/lindongdao.app`。

- [ ] **Step 7: 【人工】整体验收**

启动 `open build/lindongdao.app`，悬停展开：
- 底部有 **2 个页点**，默认在音乐页（左点亮）。
- **两指左右滑**触控板 → 在音乐页 / 文件页之间切，一次滑一页，到边不回绕。**方向若反**（关了自然滚动），告诉我，我把 PageSwipe 两个判断符号对调。
- **点页点** → 直接跳到那页。
- **滑动不触发系统切桌面/通知中心**；光标移开岛后两指滑走系统/其它 app。
- 从 Finder **拖文件到灵动岛** → 自动展开 + 跳到文件页 + 文件入架（满 10 个再拖会抖动）。文件页可拖出、× 移除、清空。
- 收起再展开 **回到上次停的页**（同次使用内）。
- 音乐页一切如常（随机/循环/进度/设备行）；面板比例协调、封面不被刘海挡、收起态不变、收起不忽然变宽。
请用户确认。

- [ ] **Step 8: 提交**

```bash
git add -A
git commit -m "feat: 展开面板改为多页（音乐/文件），接线滑动切换与拖放入文件页，删除旧单页与开关"
```

---

## 自检（写计划后核对 spec）

- **spec 覆盖**：两页+可扩展（Task 1）；纯滑动判定（Task 2）；滚动监听不冲突不拦点击（Task 3）；可点页点兜底（Task 4）；文件页整页恢复（Task 5、7）；分页容器+滑动动画+刘海内边距+尺寸（Task 6、7-1）；拖文件自动跳文件页入架（Task 7-3）；记住上次页（IslandPagesModel 常驻 + Task 7-2 注入）；去 FeatureFlags、删 ExpandedPanelView（Task 7-4）；容错（钳制不回绕 Task 1、忽略惯性 Task 3、阈值 Task 2）。全部有任务。
- **类型一致**：`IslandPage`(music/shelf)、`IslandPagesModel`(current/go/advance)、`PageSwipe.pageDelta(accumulatedX:threshold:)`、`SwipeMonitor(threshold:onPage:)`、`PageDotsView(count:current:onTap:)`、`PagedPanelView(musicVM:audioVM:shelf:pages:isDropTarget:shakeTrigger:notchHeight:)` 在各任务签名一致。
- **无占位**：每步含完整代码与命令。
- **已知风险（人工验收重点）**：① 本地滚动监听能否在 nonactivating 面板上收到事件——若收不到，退化方案是给面板 hosting view 子类重写 scrollWheel；② 滑动方向符号（自然滚动开/关）；③ 4 列网格在 340 宽下的实际观感。
