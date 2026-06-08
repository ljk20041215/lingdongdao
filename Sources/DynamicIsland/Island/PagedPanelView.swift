import SwiftUI

/// 展开面板：横向多页（音乐 / 文件中转站）+ 底部页点 + 两指滑切换。
/// 每页等宽（= 面板宽），按当前页 offset 横向滑动；黑底铺满窗口、内容下移到刘海下方。
struct PagedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var audioVM: AudioOutputViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var pages: IslandPagesModel
    let isDropTarget: Bool
    let shakeTrigger: Int
    let notchHeight: CGFloat

    @State private var monitor: SwipeMonitor?

    private var pageWidth: CGFloat { IslandLayout.expandedSize.width }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                MusicPanelView(musicVM: musicVM, audioVM: audioVM)
                    .frame(width: pageWidth)
                ShelfPanelView(store: shelf, isDropTarget: isDropTarget)
                    .modifier(ShakeEffect(trigger: CGFloat(shakeTrigger)))
                    .animation(.linear(duration: 0.4), value: shakeTrigger)
                    .frame(width: pageWidth)
            }
            .frame(width: pageWidth, alignment: .leading)
            .offset(x: -CGFloat(pages.current.rawValue) * pageWidth)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: pages.current)
            .clipped()
            .frame(maxHeight: .infinity)

            PageDotsView(count: IslandPage.allCases.count,
                         current: pages.current.rawValue) { idx in
                if let p = IslandPage(rawValue: idx) { pages.go(to: p) }
            }
        }
        .padding(.bottom, 10)
        .padding(.top, notchHeight + 4)
        .frame(maxWidth: .infinity)
        .frame(height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        .onAppear {
            let m = SwipeMonitor(threshold: 40) { delta in pages.advance(by: delta) }
            m.start()
            monitor = m
        }
        .onDisappear {
            monitor?.stop()
            monitor = nil
        }
    }
}
