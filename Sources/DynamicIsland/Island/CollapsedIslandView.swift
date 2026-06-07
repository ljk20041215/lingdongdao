import SwiftUI

/// 收起态：黑色胶囊包住刘海。播放音乐时左翼露出迷你封面、右翼露出波形；
/// 无音乐时翼宽为 0，岛与刘海完全一致。
struct CollapsedIslandView: View {
    let notchSize: CGSize
    @ObservedObject var musicVM: MusicViewModel

    private var hasMusic: Bool { musicVM.info != nil }

    var body: some View {
        HStack(spacing: 0) {
            leftChip
            Color.black.frame(width: notchSize.width, height: notchSize.height)
            rightChip
        }
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }

    private var leftChip: some View {
        Group {
            if hasMusic {
                HStack {
                    Spacer()
                    artworkThumb
                }
                .padding(.trailing, 6)
                .frame(width: IslandLayout.chipWidth, height: notchSize.height)
            }
        }
    }

    private var rightChip: some View {
        Group {
            if hasMusic {
                HStack {
                    WaveformView(isPlaying: musicVM.info?.isPlaying == true)
                    Spacer()
                }
                .padding(.leading, 6)
                .frame(width: IslandLayout.chipWidth, height: notchSize.height)
            }
        }
    }

    private var artworkThumb: some View {
        Group {
            if let artwork = musicVM.artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
