# 设计：音乐面板增强（播放模式 + 输出设备切换）

日期：2026-06-08
状态：已通过 brainstorm，待写实现计划

## 背景与目标

在现有展开面板（音乐单栏）基础上增加三个控制：

1. **随机播放** 🔀 —— 开/关
2. **循环模式** 🔁 —— 关 / 列表循环 / 单曲循环（按播放器能力自适应）
3. **系统输出设备切换** 🔊 —— 在面板内切换整机音频输出设备（影响所有 app，等同音量菜单里的设备列表）

前两个复用现有 AppleScript 音乐管线；第三个是全新的 CoreAudio 子系统，与音乐解耦。

## 一、播放模式（随机 / 循环）

### 行为
- **随机**：布尔开关。Music、Spotify 均支持。
- **循环**：点击循环切换；可切状态由"当前正在用的播放器"决定：
  - **Apple Music** 三态：`关 → 列表循环 → 单曲循环 → 关`
  - **Spotify** 两态：`关 → 开 → 关`（Spotify 的 AppleScript 无"单曲"概念）
- 按钮高亮/图标反映从播放器**读回的真实状态**，而非本地猜测。

### AppleScript 依据
- Apple Music：`shuffle enabled`（boolean，可读写）、`song repeat`（`off`/`one`/`all`，可读写）。
- Spotify：`shuffling`（boolean，可读写）、`repeating`（boolean，可读写）。

### 数据模型
- 新增 `enum RepeatMode { case off, all, one }`。
- `NowPlayingInfo` 增加：
  - `shuffle: Bool?` —— nil 表示未知/读取失败（按钮显示为禁用/默认态，不崩）
  - `repeatMode: RepeatMode?` —— 同上
- 轮询脚本在原 6 行后追加 2 行：第 7 行 shuffle、第 8 行 repeat。
  - Spotify repeat 为 `true/false`，解析为 `off` 或 `all`（无 `one`）。
  - Music repeat 为 `off/one/all` 字符串，直接映射。
- `NowPlayingParser` 容错：缺失或非法的第 7/8 行 → 对应字段 nil，不影响前 6 行解析。

### 控制
- `NowPlayingProvider` 协议新增：
  - `func setShuffle(_ on: Bool)`
  - `func setRepeat(_ mode: RepeatMode)`
- `AppleScriptMusicProvider` 按当前播放器翻译为脚本：
  - Music：`set shuffle enabled to …` / `set song repeat to off|one|all`
  - Spotify：`set shuffling to …` / `set repeating to (mode ≠ off)`
  - 控制后立即 `poll()` 刷新（沿用现有 playpause 的即时刷新模式）。
- `MusicViewModel` 暴露：`toggleShuffle()`、`cycleRepeat()`。
- **纯逻辑** `RepeatMode.next(after:supportsOne:)`：
  - supportsOne=true（Music）：`off→all→one→off`
  - supportsOne=false（Spotify）：`off→all→off`
  - 可单测，不碰 AppleScript。

## 二、系统输出设备切换（CoreAudio，新模块）

### 行为
- 面板底部一行：扬声器图标 + 当前输出设备名 + ▾。
- 点开弹出系统全部**输出**设备列表，当前项打勾；点选即把它设为系统默认输出。
- 设备增减（如 AirPods 连上/拔掉）或默认变化时，列表与当前项实时刷新。

### 模块（与音乐完全解耦，便于独立测试）
- `struct AudioDevice: Equatable { let id: AudioDeviceID; let name: String }`
- `protocol AudioOutputProviding`：
  - `func outputDevices() -> [AudioDevice]`
  - `func currentDefaultID() -> AudioDeviceID?`
  - `func setDefault(_ id: AudioDeviceID)`
  - `var onChange: (() -> Void)?`（设备列表/默认变化时回调）
- `CoreAudioOutputProvider`：真实现。
  - 列设备：`kAudioHardwarePropertyDevices` → 过滤有输出声道者（`kAudioDevicePropertyStreamConfiguration` 输出 scope 声道数 > 0）→ 取名（`kAudioObjectPropertyName`）。
  - 当前默认：`kAudioHardwarePropertyDefaultOutputDevice`。
  - 设置默认：写 `kAudioHardwarePropertyDefaultOutputDevice`。
  - 监听：对 `kAudioHardwarePropertyDevices` 与 `kAudioHardwarePropertyDefaultOutputDevice` 注册属性监听，回调 `onChange`。
- `AudioOutputViewModel: ObservableObject`：
  - `@Published private(set) var devices: [AudioDevice]`
  - `@Published private(set) var currentID: AudioDeviceID?`
  - `func refresh()`、`func select(_ id: AudioDeviceID)`
  - 持有 provider；`onChange` → 主线程 `refresh()`。
- UI：`AudioDeviceRow`（或 MusicPanelView 内子视图）——扬声器图标 + 当前名（过长截断）+ SwiftUI `Menu`，菜单项列设备、当前项打勾、点选调 `select`。
- `AppDelegate` 创建 `AudioOutputViewModel` 并注入面板，应用启动时 `refresh()` 一次。

## 三、UI 布局

- 传输行由 3 键变 5 键：`🔀 ⏮ ⏯ ⏭ 🔁`（缩小间距与图标以适配 240 宽内容区）。
- 底部新增设备行：`🔊 设备名 ▾`。
- 音乐单栏面板高度 230 → 约 280；宽度 300 不变（内容下移到刘海下方的逻辑沿用现状）。
- 文件中转站仍下线（FeatureFlags.shelfEnabled=false），本设计只动音乐单栏。

## 数据流

```
轮询(2s) ─ AppleScript ─→ NowPlayingParser ─→ NowPlayingInfo(含 shuffle/repeat)
                                                      │
                                              MusicViewModel ──→ MusicPanelView（按钮高亮）
点按钮 ─→ MusicViewModel.toggleShuffle/cycleRepeat ─→ Provider.setShuffle/setRepeat ─→ 立即 poll 刷新

CoreAudio 监听 ─→ AudioOutputProviding.onChange ─→ AudioOutputViewModel.refresh ─→ AudioDeviceRow
点设备 ─→ AudioOutputViewModel.select ─→ Provider.setDefault ─→ 系统默认输出切换
```

## 错误处理

| 情况 | 处理 |
|---|---|
| 播放器未运行 | 随机/循环按钮无反应（沿用现有 activePlayerApp 守卫） |
| Spotify 不支持"单曲" | 循环仅在它支持的态间切换（off↔all） |
| 读 shuffle/repeat 失败或缺行 | 对应字段 nil，按钮显示默认/禁用，不崩 |
| AppleScript 自动化权限被拒 | 沿用现有 PERM_DENIED 处理 |
| CoreAudio 取设备失败 | 设备列表为空 / 仅显示当前，不崩，记录日志 |
| 选中设备被拔出 | 系统自动回退默认；监听触发 refresh，UI 更新 |

## 测试策略

- **纯逻辑（单测）**：
  - `NowPlayingParser` 新增用例：解析 shuffle/repeat（Music 三态字符串、Spotify 布尔→mode）、缺行/非法 → nil。
  - `RepeatMode.next`：Music 三态循环、Spotify 两态循环。
  - `AudioOutputViewModel`：注入假 `AudioOutputProviding`，验证 refresh 更新列表/当前、select 改默认、onChange 触发刷新。
- **人工验收**：CoreAudio 真实现（切设备听声/看系统设置）、面板布局观感、按钮高亮随真实播放器状态变化。

## 实现顺序（写计划时据此分块）

1. **Slice A — 播放模式**：数据模型 + 解析器 + 控制命令 + VM + 按钮。便宜、复用现有，先做。
2. **Slice B — CoreAudio 设备模块**：协议 + 真实现 + VM（含假 Provider 单测）。
3. **Slice C — UI 整合**：传输行扩成 5 键、底部设备行、面板尺寸调整、AppDelegate 接线。

## YAGNI（明确不做）

- 单 app 音频路由（macOS 原生做不到，需虚拟声卡）。
- 输出音量 / 平衡 / EQ 控制。
- 输入（麦克风）设备切换。
- 设备分组、AirPlay 高级命名、每设备记忆音量等。
