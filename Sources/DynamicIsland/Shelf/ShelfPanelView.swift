import SwiftUI
import UniformTypeIdentifiers

/// 展开面板右侧的文件架
struct ShelfPanelView: View {
    @ObservedObject var store: ShelfStore
    let isDropTarget: Bool

    private let columns = Array(repeating: GridItem(.fixed(56), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if store.items.isEmpty {
                emptyHint
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(store.items) { item in
                        ShelfItemView(item: item,
                                      isMissing: store.isMissing(item),
                                      onRemove: { store.remove(item.id) })
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        Text("放在这里")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.blue)
                    }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("文件架 \(store.items.count)/\(ShelfStore.maxItems)")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            Spacer()
            if !store.items.isEmpty {
                Button("清空") { store.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 22))
                .foregroundStyle(.gray)
            Text("拖文件到这里暂存")
                .font(.system(size: 11))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 单个文件项：缩略图 + 文件名；hover 显示 × 移除；失效灰显；可拖出
struct ShelfItemView: View {
    let item: ShelfItem
    let isMissing: Bool
    let onRemove: () -> Void

    @StateObject private var thumbnail = ThumbnailLoader()
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                if hovering {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 5, y: -5)
                }
            }
            Text(item.url.lastPathComponent)
                .font(.system(size: 9))
                .foregroundStyle(isMissing ? .gray.opacity(0.5) : .gray)
                .lineLimit(1)
                .frame(width: 56)
        }
        .opacity(isMissing ? 0.4 : 1)
        .onHover { hovering = $0 }
        .onAppear { thumbnail.load(url: item.url) }
        // 拖出到 Finder / 任意应用。失效文件禁止拖出。
        .onDrag {
            isMissing ? NSItemProvider() : (NSItemProvider(contentsOf: item.url) ?? NSItemProvider())
        }
    }

    private var thumbnailImage: some View {
        Group {
            if let image = thumbnail.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 18))
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 44, height: 44)
    }
}
