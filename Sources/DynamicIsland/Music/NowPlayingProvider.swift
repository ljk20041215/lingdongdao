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
