import SwiftUI
import UniformTypeIdentifiers

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    @ObservedObject var shelf: ShelfStore
    let notchSize: CGSize

    @State private var dropTargeted = false
    @State private var shakeTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize, musicVM: musicVM)
            case .expanded, .dropTarget:
                ExpandedPanelView(musicVM: musicVM,
                                  shelf: shelf,
                                  isDropTarget: viewModel.state == .dropTarget,
                                  shakeTrigger: shakeTrigger)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        // 文件拖到岛的任何位置：悬停 → dropTarget 态展开；松手 → 入架
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            viewModel.dropStarted()
            Self.loadFileURLs(from: providers) { urls in
                let rejected = shelf.add(urls: urls)
                if !rejected.isEmpty { shakeTrigger += 1 }   // 满架抖动
                viewModel.send(.dropCompleted)
            }
            return true
        }
        .onChange(of: dropTargeted) { _, targeted in
            viewModel.setDragTargeted(targeted)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
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
