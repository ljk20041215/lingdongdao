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
            do {
                _ = try self.runner.run("tell application \"\(app)\" to \(command)")
            } catch ScriptError.permissionDenied {
                self.reportPermissionDenied()
            } catch {}
            self.poll()   // 立即刷新，不等下个轮询周期
        }
    }

    // MARK: - 轮询

    private func poll() {
        guard let app = activePlayerApp() else {
            publishNothingPlaying()
            return
        }
        do {
            let script = app == "Spotify" ? Self.spotifyScript : Self.musicScript
            let raw = try runner.run(script).stringValue ?? ""
            if raw == "PERM_DENIED" {
                reportPermissionDenied()
                publishNothingPlaying()
                return
            }
            let source: NowPlayingInfo.Source = app == "Spotify" ? .spotify : .music
            guard let info = NowPlayingParser.parse(raw, source: source) else {
                publishNothingPlaying()
                return
            }
            permissionReported = false   // 授权已恢复：用户再次撤销时提示需能重新出现
            publish(info)
            fetchArtworkIfNeeded(for: info)
        } catch ScriptError.permissionDenied {
            reportPermissionDenied()
            publishNothingPlaying()
        } catch {
            publishNothingPlaying()
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

    /// 停止播放时同时清掉封面 key：VM 已把封面清空，下次同一首歌需要重新获取
    private func publishNothingPlaying() {
        lastArtworkKey = nil
        publish(nil)
    }

    private func reportPermissionDenied() {
        guard !permissionReported else { return }
        permissionReported = true
        DispatchQueue.main.async { [weak self] in self?.onPermissionDenied?() }
    }

    // MARK: - 封面

    private func fetchArtworkIfNeeded(for info: NowPlayingInfo) {
        let key = "\(info.source.rawValue)|\(info.title)|\(info.artist)"
        guard key != lastArtworkKey else { return }
        lastArtworkKey = key

        if let url = info.artworkURL {
            // Spotify：封面是 https URL。完成时若曲目已切换则丢弃，防止旧封面覆盖新封面
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                let image = data.flatMap(NSImage.init(data:))
                self?.queue.async {
                    guard self?.lastArtworkKey == key else { return }
                    DispatchQueue.main.async { self?.onArtwork?(image) }
                }
            }.resume()
        } else if info.source == .music {
            // Apple Music：封面走 artwork data 查询，失败则降级为 nil（UI 显示占位图标）
            let image = (try? runner.run(Self.musicArtworkScript))
                .flatMap { $0.data.isEmpty ? nil : NSImage(data: $0.data) }
            // 同步路径下该守卫当前恒真，仅作为未来改异步时的防御
            guard lastArtworkKey == key else { return }
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
    on error msg number n
        if n is -1743 then return "PERM_DENIED"
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
    on error msg number n
        if n is -1743 then return "PERM_DENIED"
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
