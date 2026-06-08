# 设计：灵动岛多页 + 左右滑切换

日期：2026-06-09
状态：已通过 brainstorm，待写实现计划

## 背景与目标

当前展开面板只有音乐一页（文件中转站已下线）。把展开面板改成**多页**，可在页之间左右滑切换（像手机灵动岛），让不同功能各占一页、互不挤占。第一版两页：

1. **音乐页**（现有音乐面板，原样）
2. **文件中转站页**（恢复下线的中转站，独立成整页）

结构上做成可扩展的页列表，以后加页只是往列表加一项。

## 一、页与切换

### 页
- `enum IslandPage: Int, CaseIterable { case music, shelf }`（rawValue 即页序，CaseIterable 给顺序与数量）。加页 = 加一个 case。
- 当前页存于一个常驻的小 ObservableObject（`IslandPagesModel`，由 AppDelegate 创建并注入），这样收起再展开能**记住上次停的页**（同一次使用内；不跨重启）。默认 `.music`。

### 切换方式（两条并存）
- **两指左右滑触控板**翻页：用一层 AppKit 捕获滚动事件的水平位移。
  - 不与系统冲突：切桌面/全屏是三/四指（手指数不同）；两指水平滑是 app 级滚动事件，只发给光标下的窗口——翻页时光标在岛上，事件归岛。
  - 一次滑动只翻一页：按 `NSEvent.phase` 累计 `.changed` 阶段的 `scrollingDeltaX`，到 `.ended` 时若累计位移过阈值则按方向翻一页；**忽略 momentum 阶段**避免惯性多翻。无精确增量的旧触控板退化为阈值判定。
  - 边界**钳制不回绕**（第一页再往右、末页再往左都不动），与页点位置语义一致。
- **底部页点** `●○`：显示当前页；**可点**，点哪个跳哪页。这是稳的兜底，手势不准也一定切得动。

### 翻页动画
- 所有页排成横向 HStack，容器裁剪到一页宽，按 `offset(x: -current * pageWidth)` 滑动，弹簧动画。

### 收起态
- **不变**：仍是音乐迷你视图（封面/波形）。翻页只发生在展开后；收起态是"始终瞥一眼"的东西，不随页变。

## 二、文件中转站页（恢复）

- 把下线的中转站**作为整页恢复**：占满整页的文件网格（最多 10、缩略图、拖出、×移除、失效灰显——逻辑全现成，只是从"右半栏"改为"整页"宽度/列数）。
- **拖文件到灵动岛** → 自动展开 + 跳到文件页 + 入架（顺带解决最初"拖文件不展开"）。落点在岛任意位置即可。
- 去掉 `FeatureFlags.shelfEnabled` 开关（使命完成）；中转站常驻为第二页。

## 三、面板尺寸与布局

- 所有页**共用一个面板尺寸**（横向滑动、每页等宽）。取能装下两者的大小：约 **340 × 300**。音乐内容居中，文件网格（5 列）放得下。
- 沿用现有：内容上方留刘海高度（封面不被遮）、面板宽度填满窗口（= max(面板宽, 刘海+两翼)，收起不忽然变宽）。
- 页点固定在面板底部。

## 四、架构（模块）

- `IslandPage`（enum）+ `IslandPagesModel: ObservableObject`（`@Published var current: IslandPage`、`go(to:)`、`advance(by:)` 带钳制）。
- **纯逻辑** `PageSwipe.decide(accumulatedX:current:count:threshold:) -> IslandPage`（位移→目标页：方向、阈值、钳制、一滑一页）。可单测。
- `ScrollSwipeCatcher`（NSViewRepresentable）：捕获 scrollWheel 的水平位移，按 phase 累计，结束时调 `onSwipe(dx)`。不污染别处。
- `PagedPanelView`（替代现 `ExpandedPanelView` 的角色）：横向 pager + 页点 + 接 swipe；持 `IslandPagesModel`。
- 页内容：音乐页 = 现 `MusicPanelView`（音频设备行仍留在音乐页，本设计不动它）；文件页 = `ShelfPageView`（由现 `ShelfPanelView` 适配整页）。
- `IslandRootView`：展开态渲染 `PagedPanelView`；拖放 onDrop 重新启用——落下即 `pages.go(to: .shelf)` + `shelf.add` + 保持展开。
- `AppDelegate`：创建并注入 `IslandPagesModel`。

## 数据流

```
两指滑 ─ ScrollSwipeCatcher(累计dx) ─→ PageSwipe.decide ─→ IslandPagesModel.current ─→ PagedPanelView 滑动
点页点 ─→ IslandPagesModel.go(to:) ─→ 同上
拖文件落到岛 ─→ shelf.add + pages.go(to:.shelf) + 保持展开 ─→ 跳到文件页显示新文件
收起→展开 ─→ 读 IslandPagesModel.current（记住上次页）
```

## 错误处理

| 情况 | 处理 |
|---|---|
| 第一页再右滑 / 末页再左滑 | 钳制不动，不回绕 |
| 触控板无精确增量/无 phase | 退化为累计阈值判定；页点照常可用 |
| momentum 惯性滚动 | 忽略，避免一甩翻多页 |
| 光标不在岛上时两指滑 | 走系统/其它 app，互不干扰（合理预期） |
| 文件页空 | 显示"拖文件到这里暂存"提示（现成） |
| 拖入超过上限 10 | 多出的被拒、满架抖动（现成） |

## 测试策略

- **纯逻辑单测**：`PageSwipe.decide`（左右方向、过/不过阈值、首末页钳制、一滑一页）；`IslandPagesModel.advance/go` 的钳制与记忆。
- **人工验收**：两指滑手感与不与系统手势冲突、页点点击跳页、拖文件自动跳文件页并入架、面板尺寸/布局、收起态不变、记住上次页。

## 实现顺序（写计划据此分块）

1. **页模型 + 纯滑动逻辑**（IslandPage / IslandPagesModel / PageSwipe，带单测）。
2. **滑动捕获**（ScrollSwipeCatcher，AppKit）。
3. **分页容器 + 页点**（PagedPanelView，接 1+2）。
4. **文件页恢复**（ShelfPageView 整页化，去开关）。
5. **接线**（IslandRootView/AppDelegate 接入、拖文件入文件页、面板尺寸、删 ExpandedPanelView 旧角色）。

## YAGNI（明确不做）

- 不跨重启记忆页（仅同次使用内）。
- 不做翻页回绕、页重排、竖向翻页。
- 收起态不随页变（不做"每页不同的收起样式"）。
- 音频设备行暂不独立成页（留在音乐页）。
