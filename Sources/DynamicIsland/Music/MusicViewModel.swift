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
