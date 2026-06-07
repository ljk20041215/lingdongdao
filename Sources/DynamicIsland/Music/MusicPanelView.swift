import SwiftUI

/// 展开面板左侧的音乐区
struct MusicPanelView: View {
    @ObservedObject var musicVM: MusicViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if musicVM.needsAutomationPermission {
                permissionHint
            } else if let info = musicVM.info {
                playingContent(info)
            } else {
                notPlaying
            }
        }
        .frame(width: 240, alignment: .leading)
    }

    private func playingContent(_ info: NowPlayingInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(info.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
            ProgressView(value: min(info.positionSec, info.durationSec),
                         total: max(info.durationSec, 1))
                .tint(.white)
            HStack(spacing: 28) {
                controlButton("backward.fill") { musicVM.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill") { musicVM.playPause() }
                controlButton("forward.fill") { musicVM.nextTrack() }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var artworkView: some View {
        Group {
            if let artwork = musicVM.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.08))
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var notPlaying: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .foregroundStyle(.gray)
            Text("未在播放")
                .font(.system(size: 12))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundStyle(.yellow)
            Text("需要自动化权限才能读取播放信息")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Text("系统设置 → 隐私与安全性 → 自动化")
                .font(.system(size: 10))
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
