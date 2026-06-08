import SwiftUI

struct ExpandedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var audioVM: AudioOutputViewModel
    let isDropTarget: Bool
    let shakeTrigger: Int
    /// 物理刘海高度：内容上方留出这么多，避免封面/文字被刘海遮挡。
    /// 黑色背景仍铺到屏幕顶（衬在刘海后方，浑然一体），只有内容下移到刘海下方。
    let notchHeight: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            MusicPanelView(musicVM: musicVM, audioVM: audioVM)
            if FeatureFlags.shelfEnabled {
                Divider().overlay(.gray.opacity(0.4))
                ShelfPanelView(store: shelf, isDropTarget: isDropTarget)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .padding(.top, notchHeight + 4)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .modifier(ShakeEffect(trigger: CGFloat(shakeTrigger)))
        .animation(.linear(duration: 0.4), value: shakeTrigger)
    }
}
