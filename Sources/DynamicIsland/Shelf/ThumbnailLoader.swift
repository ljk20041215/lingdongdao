import AppKit
import QuickLookThumbnailing

/// 为单个文件异步生成缩略图；失败降级为系统文件图标
final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    func load(url: URL, side: CGFloat = 44) {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: side, height: side),
            scale: 2,
            representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            DispatchQueue.main.async {
                self?.image = rep?.nsImage ?? NSWorkspace.shared.icon(forFile: url.path)
            }
        }
    }
}
