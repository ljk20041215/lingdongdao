import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var audioVM: AudioOutputViewModel
    @ObservedObject var pages: IslandPagesModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            // 悬停区贴着可见的岛本身（收起态=小岛，展开态=面板），不覆盖整个窗口：
            // 收起后窗口要等 0.4s 才缩小，期间面板原位的透明区不应再触发展开
            islandContent
                .contentShape(Rectangle())
                .onHover { viewModel.setHovered($0) }
                // 弹簧只作用在内容切换上：窗口缩放（透明）瞬时，只有岛内容在动，
                // 临界阻尼 1.0 无过冲，收起不回弹
                .animation(.spring(response: 0.34, dampingFraction: 1.0), value: viewModel.state)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 文件投放在 AppKit 层接收（见 FileDropView / IslandWindowController），不再用 SwiftUI onDrop
    }

    @ViewBuilder
    private var islandContent: some View {
        switch viewModel.state {
        case .collapsed:
            CollapsedIslandView(notchSize: notchSize,
                                musicVM: musicVM,
                                shelf: shelf,
                                pages: pages)
        case .expanded, .dropTarget:
            PagedPanelView(musicVM: musicVM,
                           audioVM: audioVM,
                           shelf: shelf,
                           pages: pages,
                           isDropTarget: viewModel.state == .dropTarget,
                           notchHeight: notchSize.height,
                           panelWidth: notchSize.width + IslandLayout.chipWidth * 2)
        }
    }
}
