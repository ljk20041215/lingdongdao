import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicVM: MusicViewModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize, musicVM: musicVM)
            case .expanded, .dropTarget:
                ExpandedPanelView(musicVM: musicVM)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
    }
}
