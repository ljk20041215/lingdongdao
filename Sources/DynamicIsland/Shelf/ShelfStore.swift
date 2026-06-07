import Foundation

/// 文件架数据层：保存文件引用（不复制文件本体），JSON 持久化。
/// storeURL 与 fileExists 注入以便测试。
final class ShelfStore: ObservableObject {
    static let maxItems = 10

    @Published private(set) var items: [ShelfItem] = []

    private let storeURL: URL
    private let fileExists: (URL) -> Bool

    init(storeURL: URL = ShelfStore.defaultStoreURL,
         fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.storeURL = storeURL
        self.fileExists = fileExists
        load()
    }

    static var defaultStoreURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lindongdao/shelf.json")
    }

    /// 返回因超出上限被拒绝的 URL（重复项静默忽略，不算拒绝）
    @discardableResult
    func add(urls: [URL]) -> [URL] {
        var rejected: [URL] = []
        for url in urls {
            if items.contains(where: { $0.url == url }) { continue }
            if items.count >= Self.maxItems {
                rejected.append(url)
                continue
            }
            items.append(ShelfItem(id: UUID(), url: url, addedAt: Date()))
        }
        save()
        return rejected
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    /// 源文件被删除/移动 → UI 灰显（spec 错误处理表）
    func isMissing(_ item: ShelfItem) -> Bool {
        !fileExists(item.url)
    }

    // MARK: - 持久化（失败静默：文件架丢失不应让应用崩溃）

    private func save() {
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storeURL, options: .atomic)   // 原子写入：中断不会留下截断文件
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = decoded
    }
}
