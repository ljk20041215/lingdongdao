import SwiftUI

struct ExpandedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    let isDropTarget: Bool
    let shakeTrigger: Int

    var body: some View {
        HStack(spacing: 16) {
            MusicPanelView(musicVM: musicVM)
            if FeatureFlags.shelfEnabled {
                Divider().overlay(.gray.opacity(0.4))
                ShelfPanelView(store: shelf, isDropTarget: isDropTarget)
            }
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .modifier(ShakeEffect(trigger: CGFloat(shakeTrigger)))
        .animation(.linear(duration: 0.4), value: shakeTrigger)
    }
}
