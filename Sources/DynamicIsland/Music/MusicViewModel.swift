import AppKit

final class MusicViewModel: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var needsAutomationPermission = false

    /// info 最近一次刷新的时刻，供进度条在两次轮询之间本地平滑推进（见 PlaybackProgress）
    private(set) var syncedAt = Date()

    private let provider: NowPlayingProvider

    init(provider: NowPlayingProvider) {
        self.provider = provider
        provider.onUpdate = { [weak self] info in
            guard let self else { return }
            self.info = info
            self.syncedAt = Date()
            if info == nil { self.artwork = nil }
            // 拿到真实数据说明授权已恢复，清除过期的授权提示
            if info != nil { self.needsAutomationPermission = false }
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

    func toggleShuffle() {
        provider.setShuffle(!(info?.shuffle ?? false))
    }

    func cycleRepeat() {
        let current = info?.repeatMode ?? .off
        provider.setRepeat(current.next(supportsOne: info?.source == .music))
    }
}
