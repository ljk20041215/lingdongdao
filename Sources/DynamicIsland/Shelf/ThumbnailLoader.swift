import AppKit
import QuickLookThumbnailing

/// 为单个文件异步生成缩略图；失败降级为系统文件图标。
/// 进程内缓存：折叠/展开会重建视图，缓存避免每次展开都闪占位图。
final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private static let cache = NSCache<NSURL, NSImage>()

    func load(url: URL, side: CGFloat = 44) {
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: 2,
            representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            let result = rep?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path)
            DispatchQueue.main.async {
                Self.cache.setObject(result, forKey: url as NSURL)
                self?.image = result
            }
        }
    }
}
