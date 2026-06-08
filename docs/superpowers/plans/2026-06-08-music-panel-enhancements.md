# 音乐面板增强（播放模式 + 输出设备）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在展开音乐面板加入随机/循环播放控制，以及系统输出设备切换。

**Architecture:** 播放模式复用现有 AppleScript 轮询/控制管线（扩展数据模型、解析器、控制命令、UI 按钮）；输出设备切换是独立的 CoreAudio 模块（协议 + 真实现 + 可测 ViewModel + 面板底部设备行）。

**Tech Stack:** Swift / SwiftUI / AppKit / AppleScript / CoreAudio；SwiftPM；XCTest（纯逻辑 TDD，AppleScript 与 CoreAudio 硬件交互人工验收）。

**全局须知：** 工作目录 `~/Desktop/lindongdao`。构建 `swift build`；测试 `swift test`；重新打包 `./scripts/make_app.sh`。`【人工】` 标记需运行 app 由用户确认的步骤。文件中转站仍下线（`FeatureFlags.shelfEnabled=false`），本计划只动音乐单栏。

---

## 文件结构

- 新建 `Sources/DynamicIsland/Music/RepeatMode.swift` —— 循环模式枚举 + 纯切换逻辑
- 改 `Sources/DynamicIsland/Music/NowPlayingInfo.swift` —— 增加 shuffle/repeatMode 字段
- 改 `Sources/DynamicIsland/Music/NowPlayingParser.swift` —— 解析第 7/8 行
- 改 `Sources/DynamicIsland/Music/NowPlayingProvider.swift` —— 协议加 setShuffle/setRepeat
- 改 `Sources/DynamicIsland/Music/AppleScriptMusicProvider.swift` —— 脚本多读两行 + 控制命令
- 改 `Sources/DynamicIsland/Music/MusicViewModel.swift` —— toggleShuffle/cycleRepeat
- 改 `Sources/DynamicIsland/Music/MusicPanelView.swift` —— 随机/循环按钮 + 设备行
- 新建 `Sources/DynamicIsland/Audio/AudioDevice.swift`
- 新建 `Sources/DynamicIsland/Audio/AudioOutputProviding.swift`
- 新建 `Sources/DynamicIsland/Audio/AudioOutputViewModel.swift`
- 新建 `Sources/DynamicIsland/Audio/CoreAudioOutputProvider.swift`
- 新建 `Sources/DynamicIsland/Audio/AudioDeviceRow.swift`
- 改 `Sources/DynamicIsland/App/AppDelegate.swift` —— 创建 audioVM 并接线
- 改 `Sources/DynamicIsland/Island/IslandRootView.swift` —— 透传 audioVM
- 改 `Sources/DynamicIsland/Island/ExpandedPanelView.swift` —— 透传 audioVM
- 改 `Sources/DynamicIsland/Island/IslandLayout.swift` —— 面板高度 230→280
- 新建测试：`RepeatModeTests.swift`、`AudioOutputViewModelTests.swift`；扩 `NowPlayingParserTests.swift`

---

## Slice A —— 播放模式（随机 / 循环）

### Task 1: RepeatMode 枚举 + 切换逻辑

**Files:**
- Create: `Sources/DynamicIsland/Music/RepeatMode.swift`
- Test: `Tests/DynamicIslandTests/RepeatModeTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/DynamicIslandTests/RepeatModeTests.swift`:
```swift
import XCTest
@testable import DynamicIsland

final class RepeatModeTests: XCTestCase {
    func testMusicCyclesThreeStates() {
        XCTAssertEqual(RepeatMode.off.next(supportsOne: true), .all)
        XCTAssertEqual(RepeatMode.all.next(supportsOne: true), .one)
        XCTAssertEqual(RepeatMode.one.next(supportsOne: true), .off)
    }
    func testSpotifySkipsOne() {
        XCTAssertEqual(RepeatMode.off.next(supportsOne: false), .all)
        XCTAssertEqual(RepeatMode.all.next(supportsOne: false), .off)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter RepeatModeTests`
Expected: 编译失败（`RepeatMode` 未定义）。

- [ ] **Step 3: 写最小实现**

`Sources/DynamicIsland/Music/RepeatMode.swift`:
```swift
/// 循环模式。rawValue 与 Apple Music 的 song repeat 常量名一致（off/all/one），
/// 直接拼进 AppleScript 即为对应常量。
enum RepeatMode: String, Equatable {
    case off, all, one

    /// 按播放器能力切到下一个模式。
    /// supportsOne=true（Apple Music）：off→all→one→off
    /// supportsOne=false（Spotify，无单曲）：off→all→off
    func next(supportsOne: Bool) -> RepeatMode {
        switch self {
        case .off: return .all
        case .all: return supportsOne ? .one : .off
        case .one: return .off
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter RepeatModeTests`
Expected: PASS（2 个测试）。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Music/RepeatMode.swift Tests/DynamicIslandTests/RepeatModeTests.swift
git commit -m "feat: RepeatMode 枚举与按播放器自适应的切换逻辑"
```

---

### Task 2: NowPlayingInfo 增加 shuffle / repeatMode 字段

**Files:**
- Modify: `Sources/DynamicIsland/Music/NowPlayingInfo.swift`

- [ ] **Step 1: 加字段**

把 `NowPlayingInfo` 改为（在 `artworkURL` 后追加两个可选字段；可选字段在 memberwise init 里默认 nil，现有构造处无需改动）：
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
    var shuffle: Bool?     // nil = 未知/读取失败
    var repeatMode: RepeatMode?
}
```

- [ ] **Step 2: 跑全量测试确认未破坏现有**

Run: `swift test`
Expected: 全部 PASS（新增可选字段默认 nil，现有解析/构造不受影响）。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Music/NowPlayingInfo.swift
git commit -m "feat: NowPlayingInfo 增加 shuffle/repeatMode 字段"
```

---

### Task 3: 解析器读取第 7/8 行（shuffle / repeat）

**Files:**
- Modify: `Sources/DynamicIsland/Music/NowPlayingParser.swift`
- Test: `Tests/DynamicIslandTests/NowPlayingParserTests.swift`

- [ ] **Step 1: 写失败测试（追加到 NowPlayingParserTests）**

在 `NowPlayingParserTests` 类内追加：
```swift
    func testParsesSpotifyShuffleAndRepeat() {
        // Spotify 第 7 行 shuffling、第 8 行 repeating，均为 true/false
        let raw = "S\nA\n10\n200\nplaying\nhttps://x\ntrue\ntrue"
        let info = NowPlayingParser.parse(raw, source: .spotify)
        XCTAssertEqual(info?.shuffle, true)
        XCTAssertEqual(info?.repeatMode, .all)   // Spotify true → all
    }

    func testParsesMusicShuffleAndRepeat() {
        // Music 第 6 行空（封面占位）、第 7 行 shuffle、第 8 行 song repeat
        let raw = "S\nA\n10\n200\nplaying\n\nfalse\none"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertEqual(info?.shuffle, false)
        XCTAssertEqual(info?.repeatMode, .one)
    }

    func testMissingShuffleRepeatStaysNil() {
        // 旧的 6 行输出：shuffle/repeat 应为 nil，不影响其余解析
        let raw = "S\nA\n10\n200\nplaying\n"
        let info = NowPlayingParser.parse(raw, source: .music)
        XCTAssertNil(info?.shuffle)
        XCTAssertNil(info?.repeatMode)
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter NowPlayingParserTests`
Expected: 新增 3 个测试 FAIL（shuffle/repeatMode 当前恒为 nil）。

- [ ] **Step 3: 实现解析**

把 `NowPlayingParser.swift` 改为：
```swift
import Foundation

enum NowPlayingParser {
    /// 解析 AppleScript 输出。格式：标题\n歌手\n位置\n时长\n状态\n封面URL\n随机\n循环
    static func parse(_ raw: String, source: NowPlayingInfo.Source) -> NowPlayingInfo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lines = raw.components(separatedBy: "\n")
        guard lines.count >= 5 else { return nil }
        guard let position = parseNumber(lines[2]),
              let duration = parseNumber(lines[3]),
              position.isFinite, duration.isFinite,
              position >= 0, duration >= 0 else { return nil }
        let state = lines[4].trimmingCharacters(in: .whitespaces).lowercased()
        let artworkRaw = lines.count >= 6 ? lines[5].trimmingCharacters(in: .whitespaces) : ""
        return NowPlayingInfo(
            source: source,
            title: lines[0],
            artist: lines[1],
            isPlaying: state == "playing",
            positionSec: position,
            durationSec: duration,
            artworkURL: artworkRaw.isEmpty ? nil : URL(string: artworkRaw),
            shuffle: lines.count >= 7 ? parseBool(lines[6]) : nil,
            repeatMode: lines.count >= 8 ? parseRepeat(lines[7], source: source) : nil)
    }

    /// AppleScript 数字可能用逗号作小数点（地区设置），统一替换后解析
    private static func parseNumber(_ s: String) -> Double? {
        Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private static func parseBool(_ s: String) -> Bool? {
        switch s.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    /// Music 给 off/one/all 字符串；Spotify 给 true/false（true→all）
    private static func parseRepeat(_ s: String, source: NowPlayingInfo.Source) -> RepeatMode? {
        let v = s.trimmingCharacters(in: .whitespaces).lowercased()
        switch source {
        case .music:
            switch v {
            case "off": return .off
            case "one": return .one
            case "all": return .all
            default: return nil
            }
        case .spotify:
            switch v {
            case "true": return .all
            case "false": return .off
            default: return nil
            }
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter NowPlayingParserTests`
Expected: 全部 PASS（含原有 6 个 + 新增 3 个）。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Music/NowPlayingParser.swift Tests/DynamicIslandTests/NowPlayingParserTests.swift
git commit -m "feat: 解析器读取随机/循环状态（Music 三态、Spotify 布尔）"
```

---

### Task 4: 脚本多读两行 + 控制命令 setShuffle/setRepeat

**Files:**
- Modify: `Sources/DynamicIsland/Music/NowPlayingProvider.swift`
- Modify: `Sources/DynamicIsland/Music/AppleScriptMusicProvider.swift`
- Modify: `Sources/DynamicIsland/Music/MusicViewModel.swift`

无新单测（控制路径依赖 NSRunningApplication 检测真实运行的应用，与现有 playPause 等一致，不可单测）；纯逻辑已在 Task 1/3 覆盖。本任务以编译 + 人工验收为准。

- [ ] **Step 1: 协议加两个方法**

`NowPlayingProvider.swift`，在 `func previousTrack()` 后追加：
```swift
    func setShuffle(_ on: Bool)
    func setRepeat(_ mode: RepeatMode)
```

- [ ] **Step 2: 脚本追加 shuffle/repeat 两行**

`AppleScriptMusicProvider.swift`，把 `spotifyScript` 整体替换为：
```swift
    /// Spotify duration 单位是毫秒，这里换算成秒；末两行为随机/循环（均布尔）
    static let spotifyScript = """
    try
        tell application "Spotify"
            if player state is stopped then return ""
            set t to current track
            return name of t & "\\n" & artist of t & "\\n" & (player position as text) & "\\n" & ((duration of t) / 1000 as text) & "\\n" & (player state as text) & "\\n" & artwork url of t & "\\n" & (shuffling as text) & "\\n" & (repeating as text)
        end tell
    on error msg number n
        if n is -1743 then return "PERM_DENIED"
        return ""
    end try
    """
```
把 `musicScript` 整体替换为（第 6 行保持为空作封面占位，第 7 行 shuffle、第 8 行 repeat；song repeat 常量显式映射为字符串）：
```swift
    static let musicScript = """
    try
        tell application "Music"
            if player state is stopped then return ""
            set t to current track
            set rpt to "off"
            if (song repeat is one) then set rpt to "one"
            if (song repeat is all) then set rpt to "all"
            return name of t & "\\n" & artist of t & "\\n" & (player position as text) & "\\n" & (duration of t as text) & "\\n" & (player state as text) & "\\n" & "" & "\\n" & (shuffle enabled as text) & "\\n" & rpt
        end tell
    on error msg number n
        if n is -1743 then return "PERM_DENIED"
        return ""
    end try
    """
```

- [ ] **Step 3: provider 实现控制命令**

`AppleScriptMusicProvider.swift`，在 `func previousTrack() { control("previous track") }` 后追加（复用 `control()` 与 Spotify 优先的 `isRunning`，二者判定一致，命令属性名与所选 app 对齐）：
```swift
    func setShuffle(_ on: Bool) {
        control(isRunning(Self.spotifyBundleID)
            ? "set shuffling to \(on)"
            : "set shuffle enabled to \(on)")
    }

    func setRepeat(_ mode: RepeatMode) {
        if isRunning(Self.spotifyBundleID) {
            control("set repeating to \(mode != .off)")
        } else {
            // mode.rawValue（off/all/one）作为裸词注入，即 AppleScript 的 song repeat 常量
            control("set song repeat to \(mode.rawValue)")
        }
    }
```

- [ ] **Step 4: VM 暴露开关方法**

`MusicViewModel.swift`，在 `func previousTrack() { provider.previousTrack() }` 后追加：
```swift
    func toggleShuffle() {
        provider.setShuffle(!(info?.shuffle ?? false))
    }

    func cycleRepeat() {
        let current = info?.repeatMode ?? .off
        provider.setRepeat(current.next(supportsOne: info?.source == .music))
    }
```

- [ ] **Step 5: 编译 + 全量测试**

Run: `swift build && swift test`
Expected: 构建成功；38+ 测试全 PASS（行为未变，仅新增 API）。

- [ ] **Step 6: 提交**

```bash
git add Sources/DynamicIsland/Music/NowPlayingProvider.swift Sources/DynamicIsland/Music/AppleScriptMusicProvider.swift Sources/DynamicIsland/Music/MusicViewModel.swift
git commit -m "feat: 随机/循环的读取脚本与控制命令（Music/Spotify 自适应）"
```

---

### Task 5: MusicPanelView 加随机/循环按钮

**Files:**
- Modify: `Sources/DynamicIsland/Music/MusicPanelView.swift`

- [ ] **Step 1: 改传输行为 5 键**

`MusicPanelView.swift`，把 `playingContent` 里的控制 HStack：
```swift
            HStack(spacing: 28) {
                controlButton("backward.fill") { musicVM.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill") { musicVM.playPause() }
                controlButton("forward.fill") { musicVM.nextTrack() }
            }
            .frame(maxWidth: .infinity)
```
替换为：
```swift
            HStack(spacing: 18) {
                modeButton("shuffle", active: info.shuffle == true) { musicVM.toggleShuffle() }
                controlButton("backward.fill") { musicVM.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill") { musicVM.playPause() }
                controlButton("forward.fill") { musicVM.nextTrack() }
                modeButton(repeatSymbol(info.repeatMode),
                           active: (info.repeatMode ?? .off) != .off) { musicVM.cycleRepeat() }
            }
            .frame(maxWidth: .infinity)
```

- [ ] **Step 2: 加两个辅助方法**

在 `MusicPanelView` 里 `controlButton` 方法旁追加：
```swift
    private func repeatSymbol(_ mode: RepeatMode?) -> String {
        (mode ?? .off) == .one ? "repeat.1" : "repeat"
    }

    /// 模式按钮：激活时绿色，关闭时白色
    private func modeButton(_ symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(active ? Color.green : Color.white)
        }
        .buttonStyle(.plain)
    }
```

- [ ] **Step 3: 编译 + 重新打包**

Run: `swift build && ./scripts/make_app.sh`
Expected: 构建成功，生成 `build/lindongdao.app`。

- [ ] **Step 4: 【人工】验收随机/循环**

启动：`open build/lindongdao.app`。放一首歌（Music 或 Spotify），悬停展开:
- 传输行有 5 个键：随机 / 上一首 / 播放暂停 / 下一首 / 循环。
- 点随机 → 播放器随机开关切换，按钮变绿；再点 → 关、变白。
- 点循环 → Music 在 关/列表/单曲（单曲显示 `repeat.1` 图标）间循环；Spotify 在 关/开 间切换。
- 在播放器里手动改随机/循环，约 2 秒后面板按钮状态跟着变。
请用户确认上述行为。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Music/MusicPanelView.swift
git commit -m "feat: 面板加入随机/循环按钮（状态随播放器实时反映）"
```

---

## Slice B —— 系统输出设备切换（CoreAudio）

### Task 6: AudioDevice 与 AudioOutputProviding 协议

**Files:**
- Create: `Sources/DynamicIsland/Audio/AudioDevice.swift`
- Create: `Sources/DynamicIsland/Audio/AudioOutputProviding.swift`

- [ ] **Step 1: 建 AudioDevice**

`Sources/DynamicIsland/Audio/AudioDevice.swift`:
```swift
import CoreAudio

/// 一个音频输出设备。id 为 CoreAudio 的设备号。
struct AudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let name: String
}
```

- [ ] **Step 2: 建协议**

`Sources/DynamicIsland/Audio/AudioOutputProviding.swift`:
```swift
import CoreAudio

/// 输出设备数据源协议。注入以便用假实现测试 ViewModel。
protocol AudioOutputProviding: AnyObject {
    func outputDevices() -> [AudioDevice]
    func currentDefaultID() -> AudioDeviceID?
    func setDefault(_ id: AudioDeviceID)
    /// 设备增减 / 默认输出变化时回调（主线程）
    var onChange: (() -> Void)? { get set }
}
```

- [ ] **Step 3: 编译**

Run: `swift build`
Expected: 成功。

- [ ] **Step 4: 提交**

```bash
git add Sources/DynamicIsland/Audio/AudioDevice.swift Sources/DynamicIsland/Audio/AudioOutputProviding.swift
git commit -m "feat: 音频输出设备模型与数据源协议"
```

---

### Task 7: AudioOutputViewModel（TDD，假 Provider）

**Files:**
- Create: `Sources/DynamicIsland/Audio/AudioOutputViewModel.swift`
- Test: `Tests/DynamicIslandTests/AudioOutputViewModelTests.swift`

- [ ] **Step 1: 写失败测试**

`Tests/DynamicIslandTests/AudioOutputViewModelTests.swift`:
```swift
import XCTest
import CoreAudio
@testable import DynamicIsland

private final class FakeOutputProvider: AudioOutputProviding {
    var onChange: (() -> Void)?
    var devices: [AudioDevice]
    var current: AudioDeviceID?
    private(set) var setCalls: [AudioDeviceID] = []
    init(devices: [AudioDevice], current: AudioDeviceID?) {
        self.devices = devices; self.current = current
    }
    func outputDevices() -> [AudioDevice] { devices }
    func currentDefaultID() -> AudioDeviceID? { current }
    func setDefault(_ id: AudioDeviceID) { setCalls.append(id); current = id }
}

final class AudioOutputViewModelTests: XCTestCase {
    private func twoDevices() -> FakeOutputProvider {
        FakeOutputProvider(devices: [AudioDevice(id: 1, name: "A"),
                                     AudioDevice(id: 2, name: "B")], current: 1)
    }

    func testRefreshLoadsDevicesAndCurrent() {
        let vm = AudioOutputViewModel(provider: twoDevices())
        vm.refresh()
        XCTAssertEqual(vm.devices.map(\.id), [1, 2])
        XCTAssertEqual(vm.currentID, 1)
    }

    func testSelectSetsDefaultAndUpdatesCurrent() {
        let p = twoDevices()
        let vm = AudioOutputViewModel(provider: p)
        vm.refresh()
        vm.select(2)
        XCTAssertEqual(p.setCalls, [2])
        XCTAssertEqual(vm.currentID, 2)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `swift test --filter AudioOutputViewModelTests`
Expected: 编译失败（`AudioOutputViewModel` 未定义）。

- [ ] **Step 3: 实现 ViewModel**

`Sources/DynamicIsland/Audio/AudioOutputViewModel.swift`:
```swift
import Foundation
import CoreAudio

final class AudioOutputViewModel: ObservableObject {
    @Published private(set) var devices: [AudioDevice] = []
    @Published private(set) var currentID: AudioDeviceID?

    private let provider: AudioOutputProviding

    init(provider: AudioOutputProviding) {
        self.provider = provider
        provider.onChange = { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
    }

    func refresh() {
        devices = provider.outputDevices()
        currentID = provider.currentDefaultID()
    }

    func select(_ id: AudioDeviceID) {
        provider.setDefault(id)
        refresh()
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `swift test --filter AudioOutputViewModelTests`
Expected: PASS（2 个测试）。

- [ ] **Step 5: 提交**

```bash
git add Sources/DynamicIsland/Audio/AudioOutputViewModel.swift Tests/DynamicIslandTests/AudioOutputViewModelTests.swift
git commit -m "feat: AudioOutputViewModel（刷新/选择，假 Provider 可测）"
```

---

### Task 8: CoreAudioOutputProvider（真实现，人工验收）

**Files:**
- Create: `Sources/DynamicIsland/Audio/CoreAudioOutputProvider.swift`

CoreAudio 直接操作硬件，不单测；以编译 + 人工验收为准。

- [ ] **Step 1: 实现**

`Sources/DynamicIsland/Audio/CoreAudioOutputProvider.swift`:
```swift
import CoreAudio
import Foundation

/// 基于 CoreAudio 的系统输出设备读取/切换。改的是整机默认输出（影响所有 app）。
final class CoreAudioOutputProvider: AudioOutputProviding {
    var onChange: (() -> Void)?

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    init() {
        addListener(kAudioHardwarePropertyDevices)
        addListener(kAudioHardwarePropertyDefaultOutputDevice)
    }

    func outputDevices() -> [AudioDevice] {
        allDeviceIDs().compactMap { id in
            guard hasOutputChannels(id), let name = deviceName(id) else { return nil }
            return AudioDevice(id: id, name: name)
        }
    }

    func currentDefaultID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &id)
        return status == noErr ? id : nil
    }

    func setDefault(_ id: AudioDeviceID) {
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
        var deviceID = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(systemObject, &addr, 0, nil, size, &deviceID)
    }

    // MARK: - helpers

    private func address(_ selector: AudioObjectPropertySelector,
                         scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
        -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func hasOutputChannels(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        for buffer in list where buffer.mNumberChannels > 0 { return true }
        return false
    }

    private func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName)
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name)
        return status == noErr ? (name as String) : nil
    }

    private func addListener(_ selector: AudioObjectPropertySelector) {
        var addr = address(selector)
        AudioObjectAddPropertyListenerBlock(systemObject, &addr, DispatchQueue.main) { [weak self] _, _ in
            self?.onChange?()
        }
    }
}
```

- [ ] **Step 2: 编译 + 全量测试**

Run: `swift build && swift test`
Expected: 构建成功；测试全 PASS（未改动现有逻辑）。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Audio/CoreAudioOutputProvider.swift
git commit -m "feat: CoreAudio 输出设备读取/切换/监听真实现"
```

---

### Task 9: AudioDeviceRow 设备行 UI

**Files:**
- Create: `Sources/DynamicIsland/Audio/AudioDeviceRow.swift`

- [ ] **Step 1: 实现**

`Sources/DynamicIsland/Audio/AudioDeviceRow.swift`:
```swift
import SwiftUI

/// 面板底部的输出设备行：扬声器图标 + 当前设备名 + 下拉菜单切换。
struct AudioDeviceRow: View {
    @ObservedObject var audioVM: AudioOutputViewModel

    var body: some View {
        Menu {
            ForEach(audioVM.devices) { device in
                Button { audioVM.select(device.id) } label: {
                    if device.id == audioVM.currentID {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hifispeaker.fill").font(.system(size: 11))
                Text(currentName).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(.gray)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onAppear { audioVM.refresh() }
    }

    private var currentName: String {
        audioVM.devices.first { $0.id == audioVM.currentID }?.name ?? "输出设备"
    }
}
```

- [ ] **Step 2: 编译**

Run: `swift build`
Expected: 成功。

- [ ] **Step 3: 提交**

```bash
git add Sources/DynamicIsland/Audio/AudioDeviceRow.swift
git commit -m "feat: 输出设备行 UI（下拉菜单勾选切换）"
```

---

## Slice C —— UI 整合

### Task 10: 接线 audioVM + 设备行入面板 + 面板尺寸

**Files:**
- Modify: `Sources/DynamicIsland/App/AppDelegate.swift`
- Modify: `Sources/DynamicIsland/Island/IslandRootView.swift`
- Modify: `Sources/DynamicIsland/Island/ExpandedPanelView.swift`
- Modify: `Sources/DynamicIsland/Music/MusicPanelView.swift`
- Modify: `Sources/DynamicIsland/Island/IslandLayout.swift`

- [ ] **Step 1: AppDelegate 创建并接线 audioVM**

`AppDelegate.swift`，在 `private let shelf = ShelfStore()` 后追加：
```swift
    private let audioVM = AudioOutputViewModel(provider: CoreAudioOutputProvider())
```
把 `controller.show(content: IslandRootView(...))` 调用改为带上 audioVM：
```swift
        controller.show(content: IslandRootView(
            viewModel: islandVM,
            musicVM: musicVM,
            shelf: shelf,
            audioVM: audioVM,
            notchSize: geometry.notchRect.size))
```
在 `musicVM.start()` 后追加：
```swift
        audioVM.refresh()
```

- [ ] **Step 2: IslandRootView 透传 audioVM**

`IslandRootView.swift`，在 `@ObservedObject var shelf: ShelfStore` 后追加属性：
```swift
    @ObservedObject var audioVM: AudioOutputViewModel
```
在 `islandContent` 的 `.expanded, .dropTarget` 分支，把 `ExpandedPanelView(...)` 调用改为带上 audioVM：
```swift
        case .expanded, .dropTarget:
            ExpandedPanelView(musicVM: musicVM,
                              shelf: shelf,
                              audioVM: audioVM,
                              isDropTarget: viewModel.state == .dropTarget,
                              shakeTrigger: shakeTrigger,
                              notchHeight: notchSize.height)
```

- [ ] **Step 3: ExpandedPanelView 透传 audioVM**

`ExpandedPanelView.swift`，在 `@ObservedObject var shelf: ShelfStore` 后追加：
```swift
    @ObservedObject var audioVM: AudioOutputViewModel
```
把 `MusicPanelView(musicVM: musicVM)` 改为：
```swift
            MusicPanelView(musicVM: musicVM, audioVM: audioVM)
```

- [ ] **Step 4: MusicPanelView 接收 audioVM 并在底部放设备行**

`MusicPanelView.swift`，在 `@ObservedObject var musicVM: MusicViewModel` 后追加：
```swift
    @ObservedObject var audioVM: AudioOutputViewModel
```
把 `body` 改为（内容区填满高度，设备行钉在底部）：
```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if musicVM.needsAutomationPermission {
                    permissionHint
                } else if let info = musicVM.info {
                    playingContent(info)
                } else {
                    notPlaying
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            Divider().overlay(.gray.opacity(0.25))
            AudioDeviceRow(audioVM: audioVM)
        }
        .frame(width: 240, maxHeight: .infinity, alignment: .leading)
    }
```

> 说明：外层 `maxHeight: .infinity` 让 MusicPanelView 填满面板高度，内容区 Group 的 `maxHeight: .infinity` 把分隔线与设备行顶到底部。ExpandedPanelView 的固定高度 frame 会把该高度传导下来。

- [ ] **Step 5: 面板高度 230→280**

`IslandLayout.swift`，把音乐单栏尺寸：
```swift
            : CGSize(width: 300, height: 230)
```
改为：
```swift
            : CGSize(width: 300, height: 280)
```

- [ ] **Step 6: 编译 + 全量测试 + 重新打包**

Run: `swift build && swift test && ./scripts/make_app.sh`
Expected: 构建成功；测试全 PASS；生成 `build/lindongdao.app`。

- [ ] **Step 7: 【人工】整体验收**

启动：`open build/lindongdao.app`。悬停展开:
- 面板底部有设备行：扬声器图标 + 当前输出设备名 + 上下箭头。
- 点开 → 列出系统全部输出设备，当前项打勾。
- 选另一个设备（如 AirPods/外接音箱）→ 声音切过去，系统设置里默认输出也变。
- AirPods 连上/拔掉时，列表自动刷新；被拔的若是当前设备，系统回退、行显示新当前设备。
- 面板比例协调，封面不被刘海遮挡，随机/循环按钮正常。
请用户确认。

- [ ] **Step 8: 提交**

```bash
git add Sources/DynamicIsland/App/AppDelegate.swift Sources/DynamicIsland/Island/IslandRootView.swift Sources/DynamicIsland/Island/ExpandedPanelView.swift Sources/DynamicIsland/Music/MusicPanelView.swift Sources/DynamicIsland/Island/IslandLayout.swift
git commit -m "feat: 接线输出设备 VM，设备行入面板，面板高度适配"
```

---

## 自检（写计划后核对 spec）

- **spec 覆盖**：随机（Task 1/3/4/5）、循环三态/两态（Task 1/3/4/5）、CoreAudio 设备列举/切换/监听（Task 6/7/8）、设备行 UI（Task 9）、面板布局与尺寸（Task 5/10）、容错（解析 nil 容错 Task 3、控制守卫沿用现有、CoreAudio 失败返回空 Task 8）、测试策略（Task 1/3/7 单测，Task 5/8/10 人工）—— 全部有对应任务。
- **类型一致**：`RepeatMode`（off/all/one）贯穿 Task 1/3/4/5；`AudioDevice(id:name:)`、`AudioOutputProviding`(outputDevices/currentDefaultID/setDefault/onChange) 在 Task 6/7/8/9 一致；`AudioOutputViewModel`(devices/currentID/refresh/select) 在 Task 7/9/10 一致。
- **无占位**：每步含完整代码与命令。
```
