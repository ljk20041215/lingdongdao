import Foundation

/// 进度条本地平滑推进：轮询每 2 秒给一次真实位置，两次之间按墙钟时间向前推。
/// 播放时按已过时间推进、暂停时定住；钳制到 [0, duration]。每次轮询都会重新对齐，故不会漂移。
enum PlaybackProgress {
    /// - base: 最近一次轮询拿到的真实播放信息
    /// - elapsed: 距该次轮询过去的秒数（墙钟）
    static func position(base: NowPlayingInfo, elapsed: TimeInterval) -> Double {
        let advanced = base.isPlaying ? base.positionSec + max(0, elapsed) : base.positionSec
        return min(max(0, advanced), max(base.durationSec, 0))
    }
}
