import SwiftUI

/// 收起态：黑色胶囊包住刘海。内容随当前页变化：
/// 音乐页——播放时左翼露出迷你封面、右翼露出波形；无音乐时翼宽为 0，岛与刘海完全一致。
/// 文件页——左翼托盘图标、右翼文件数（呈现「文件模式」的对称胶囊，空架不显示数字）。
struct CollapsedIslandView: View {
    let notchSize: CGSize
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var pages: IslandPagesModel

    private var hasMusic: Bool { musicVM.info != nil }
    private var isShelf: Bool { pages.current == .shelf }

    var body: some View {
        HStack(spacing: 0) {
            leftChip
            Color.black.frame(width: notchSize.width, height: notchSize.height)
            rightChip
        }
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }

    @ViewBuilder
    private var leftChip: some View {
        if isShelf {
            wing(alignTrailing: true) { trayIcon }
        } else if hasMusic {
            wing(alignTrailing: true) { artworkThumb }
        }
    }

    @ViewBuilder
    private var rightChip: some View {
        if isShelf {
            wing(alignTrailing: false) { shelfCount }
        } else if hasMusic {
            wing(alignTrailing: false) { WaveformView(isPlaying: musicVM.info?.isPlaying == true) }
        }
    }

    /// 一侧翼：固定 chipWidth 宽，内容贴近刘海一侧（左翼靠右、右翼靠左）
    private func wing<Content: View>(alignTrailing: Bool,
                                     @ViewBuilder content: () -> Content) -> some View {
        HStack {
            if alignTrailing { Spacer() }
            content()
            if !alignTrailing { Spacer() }
        }
        .padding(alignTrailing ? .trailing : .leading, 6)
        .frame(width: IslandLayout.chipWidth, height: notchSize.height)
    }

    private var trayIcon: some View {
        Image(systemName: shelf.items.isEmpty ? "tray" : "tray.full.fill")
            .font(.system(size: 11))
            .foregroundStyle(.gray)
            .frame(width: 20, height: 20)
    }

    /// 文件数：有文件时显示数字；空架时占位透明（保持对称胶囊，无数字）
    @ViewBuilder
    private var shelfCount: some View {
        if shelf.items.isEmpty {
            Color.clear.frame(width: 20, height: 20)
        } else {
            Text("\(shelf.items.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
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
