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
        // 拖出到 Finder / 任意应用：交出一份「独立临时副本」（保留原文件名/扩展名）。
        // 关键：不能给原文件 URL 的引用（那样接收方拿到的是原文件本体，删它会删原文件）；
        // 这里把文件复制到临时目录再交出，原文件绝不会被移动/删除。失效文件禁止拖出。
        .onDrag {
            guard !isMissing else { return NSItemProvider() }
            let url = item.url
            let provider = NSItemProvider()
            provider.suggestedName = url.lastPathComponent
            // 传输类型用通用 public.data：避免系统按具体 UTI 的「首选扩展名」在文件名后再追加一次
            // （否则 名称.docx → 名称.docx.docx）。真正的类型由文件名里的扩展名决定，名字逐字保留。
            provider.registerFileRepresentation(forTypeIdentifier: UTType.data.identifier,
                                                 fileOptions: [],
                                                 visibility: .all) { completion in
                do {
                    let dir = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString, isDirectory: true)
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let copy = dir.appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: copy)
                    completion(copy, false, nil)   // false=非就地：交出的是独立副本，系统用完自行清理
                } catch {
                    completion(nil, false, error)
                }
                return nil
            }
            return provider
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
