# lindongdao — macOS 灵动岛 设计文档

日期：2026-06-07
状态：已与用户确认

## 背景与目标

在带刘海的 MacBook 上实现一个类似 iPhone 灵动岛（Dynamic Island）的常驻挂件。第一版包含两个核心功能：

1. **音乐播放**：显示当前播放的歌曲（封面、歌名、进度），并支持播放/暂停/切歌
2. **文件中转站**：把文件拖到刘海上暂存，稍后再拖出到其他位置或应用

技术栈：**Swift + SwiftUI**（AppKit 负责窗口层，SwiftUI 负责界面与动画）。
选型理由：窗口层级高于菜单栏、刘海几何、全屏可见、文件拖出、读取播放状态等核心难点均只有
macOS 原生 API 能干净解决；同类开源产品（boring.notch、MewNotch 等）均为此路线，可作参考。

## 整体形态

常驻后台的菜单栏级应用（`LSUIElement`，不占 Dock、不出现在 ⌘Tab）。
启动后在刘海位置覆盖一个无边框、透明背景的浮窗。岛有三个状态：

| 状态 | 触发 | 表现 |
|---|---|---|
| 收起态 | 默认 | 与刘海融为一体的黑色胶囊；播放音乐时左侧露出迷你封面、右侧露出音频波形动画；无音乐时视觉上即刘海本身 |
| 展开态 | 鼠标悬停刘海区域 | 弹簧动画向下展开为面板：左侧音乐区（大封面、歌名/歌手、进度条、上一首/播放暂停/下一首），右侧文件架网格；鼠标移开自动收起 |
| 拖放态 | 拖文件进入刘海附近 | 岛自动展开并高亮投放区；松手即存入文件架 |

## 架构与模块

```
lindongdao/
├── Package.swift                 # SwiftPM 可执行包（只需 Command Line Tools）
├── Sources/DynamicIsland/
│   ├── App/                      # main 入口、AppDelegate、NotchWindow（NSPanel 子类）、窗口定位
│   ├── Island/                   # IslandState 状态机、总容器视图、展开/收起动画
│   ├── Music/                    # NowPlayingProvider 协议、AppleScriptMusicProvider、音乐区视图
│   ├── Shelf/                    # ShelfStore（数据层）、文件架视图、拖入/拖出处理
│   └── Support/                  # NotchGeometry（刘海几何计算）、通用工具
├── Tests/DynamicIslandTests/     # 单元测试
└── scripts/                      # 打包 .app bundle 的脚本
```

各模块单一职责、通过协议/值类型通信，可独立测试：

- **NotchWindow（App）**：`NSPanel`，`.borderless`、透明背景、窗口层级设于状态栏之上，
  `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`，保证全屏下可见。
  尺寸随岛状态变化（收起=刘海尺寸略宽，展开=面板尺寸）。
- **NotchGeometry（Support）**：用 `NSScreen` 的 safe area / auxiliary area API 动态计算刘海
  宽高与位置，不硬编码，适配不同机型。纯函数，单元测试覆盖。
- **IslandState（Island）**：`collapsed / expanded / dropTarget` 状态机，驱动窗口尺寸与
  SwiftUI 弹簧动画。悬停检测用 tracking area / `onHover`。
- **NowPlayingProvider（Music）**：协议定义"读取当前曲目（标题/歌手/封面/进度/播放中）+
  控制（播放暂停/上一首/下一首）"。第一版实现 `AppleScriptMusicProvider`：每 2 秒轮询
  Apple Music 与 Spotify（谁在播放用谁；两者同时播放时优先 Spotify，因 Music 常驻后台易误判）。
  不用系统级 MediaRemote 私有框架的原因：macOS 15.4 起 Apple 收紧其访问权限，方案复杂且脆弱；
  协议已留出扩展点，后续可新增系统级实现而不动 UI。
- **ShelfStore（Shelf）**：管理文件**引用**列表（不复制文件本体）。上限 10 项；
  JSON 持久化到 Application Support，重启保留；源文件不存在时该项灰显可移除。
  拖出用原生拖放（拖到 Finder/任意应用），拖出后默认保留；每项有 × 移除按钮，另有"清空"。
  缩略图用 QuickLook 缩略图 API。

## 数据流

- 音乐：`AppleScriptMusicProvider` 定时轮询 → 发布 `NowPlayingInfo`（值类型）→ 音乐视图订阅渲染；
  控制按钮 → provider 的控制方法 → AppleScript。
- 文件架：拖入 → 解析为文件 URL → `ShelfStore.add` → 持久化 + 视图刷新；
  拖出 → `ShelfStore` 提供 URL 给系统拖放会话。
- 状态机：悬停/拖放事件 → `IslandState` 变更 → 窗口 resize + SwiftUI 动画同步进行。

## 错误处理

| 场景 | 处理 |
|---|---|
| 无音乐播放 | 收起态不显示音乐元素；展开态音乐区显示"未在播放" |
| AppleScript 自动化权限被拒 | 音乐区显示引导提示（去系统设置开启）；不崩溃、不反复弹窗 |
| 拖入非文件内容（文字、图片数据等） | 忽略，仅接受文件 URL |
| 文件架已满（10 项） | 拒绝并播放抖动动画提示 |
| 架上文件被删除/移动 | 该项灰显，可手动移除 |
| 无刘海屏幕（防御） | 按固定尺寸黑色胶囊居中顶部显示（不作为支持目标，仅不崩溃） |

## 测试策略

- **单元测试**：NotchGeometry 几何计算；ShelfStore 增删/上限/持久化/失效文件标记；
  AppleScript 返回文本的解析逻辑。
- **人工验收清单**：hover 展开/移开收起动画流畅；全屏应用下岛可见；从 Finder 拖入；
  拖出到 Finder 与第三方应用；Music 与 Spotify 各自的显示与控制；授权拒绝后的引导提示。

## 第一版明确不做（YAGNI）

设置界面（参数用常量）、开机自启、外接显示器/多屏、通知与日历、系统级 now playing、
文件本体复制存储。均已留扩展点。

## 已确认的决策记录

- 自研而非使用现成应用（boring.notch 等可作源码参考）
- 功能范围：音乐播放 + 文件中转站（第一版）
- 目标硬件：带刘海的 MacBook 内建屏
- 技术栈：Swift + SwiftUI，经与 Electron/Tauri/PyObjC/Flutter 对比后确认
- 协作模式：AI 编写代码，用户提需求与验收
