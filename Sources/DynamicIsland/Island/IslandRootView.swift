import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    let notchSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .collapsed:
                CollapsedIslandView(notchSize: notchSize)
            case .expanded, .dropTarget:
                ExpandedPanelView()
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { viewModel.send(.hoverChanged($0)) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.state)
    }
}
