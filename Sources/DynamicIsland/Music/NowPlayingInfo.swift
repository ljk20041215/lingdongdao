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
}
