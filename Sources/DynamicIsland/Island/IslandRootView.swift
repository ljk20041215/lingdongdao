import SwiftUI
import UniformTypeIdentifiers

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    @ObservedObject var audioVM: AudioOutputViewModel
    let notchSize: CGSize

    @State private var dropTargeted = false
    @State private var shakeTrigger = 0

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
        // 文件拖到岛的任何位置：悬停 → dropTarget 态展开；松手 → 入架
        // 文件架下线时整块关闭，拖文件到刘海不再触发任何状态切换
        .modifier(ShelfDropTarget(
            enabled: FeatureFlags.shelfEnabled,
            targeted: $dropTargeted,
            onDrop: { providers in
                // 同步切换状态：不依赖异步解析的时序，松手即保持展开
                viewModel.send(.dropCompleted)
                Self.loadFileURLs(from: providers) { urls in
                    let rejected = shelf.add(urls: urls)
                    if !rejected.isEmpty { shakeTrigger += 1 }   // 满架抖动
                }
                return true
            },
            onTargetChange: { viewModel.setDragTargeted($0) }))
    }

    @ViewBuilder
    private var islandContent: some View {
        switch viewModel.state {
        case .collapsed:
            CollapsedIslandView(notchSize: notchSize, musicVM: musicVM)
        case .expanded, .dropTarget:
            ExpandedPanelView(musicVM: musicVM,
                              shelf: shelf,
                              audioVM: audioVM,
                              isDropTarget: viewModel.state == .dropTarget,
                              shakeTrigger: shakeTrigger,
                              notchHeight: notchSize.height)
        }
    }

    /// NSItemProvider 异步取出文件 URL；忽略非文件内容（spec：只接受文件）
    static func loadFileURLs(from providers: [NSItemProvider],
                             completion: @escaping ([URL]) -> Void) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) { completion(urls) }
    }
}

/// 把文件投放整块行为收进一个开关：enabled=false 时既不接收拖拽也不切 dropTarget 态
private struct ShelfDropTarget: ViewModifier {
    let enabled: Bool
    @Binding var targeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool
    let onTargetChange: (Bool) -> Void

    func body(content: Content) -> some View {
        Group {
            if enabled {
                content
                    .onDrop(of: [.fileURL], isTargeted: $targeted, perform: onDrop)
                    .onChange(of: targeted) { _, t in onTargetChange(t) }
            } else {
                content
            }
        }
    }
}
