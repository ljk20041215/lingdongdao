import SwiftUI

struct ExpandedPanelView: View {
    var body: some View {
        HStack(spacing: 16) {
            Text("音乐区").foregroundStyle(.secondary)
            Divider().overlay(.gray.opacity(0.4))
            Text("文件架").foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: IslandLayout.expandedSize.width,
               height: IslandLayout.expandedSize.height - 16)
        .background(Color.black)
        .clipShape(.rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
    }
}
