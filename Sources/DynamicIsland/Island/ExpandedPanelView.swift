import SwiftUI

struct ExpandedPanelView: View {
    @ObservedObject var musicVM: MusicViewModel

    var body: some View {
        HStack(spacing: 16) {
            MusicPanelView(musicVM: musicVM)
            Divider().overlay(.gray.opacity(0.4))
            Text("文件架").foregroundStyle(.secondary)   // Task 10 替换
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }
}
