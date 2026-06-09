import AppKit

/// AppKit 层的文件投放目标。SwiftUI 的 `.onDrop` 在无边框、nonactivating、超高层级的面板上
/// 收不到拖拽事件，故在窗口 contentView 这一层用原生 `NSDraggingDestination` 直接接收文件拖放，
/// 再回调给岛状态与文件架。SwiftUI 内容作为子视图叠在上面，正常处理鼠标/滚动；本视图只管拖放。
final class FileDropView: NSView {
    private let onTargeted: (Bool) -> Void
    private let onDrop: ([URL]) -> Void

    private let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]

    init(onTargeted: @escaping (Bool) -> Void, onDrop: @escaping ([URL]) -> Void) {
        self.onTargeted = onTargeted
        self.onDrop = onDrop
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    private func hasFiles(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: urlOptions)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard hasFiles(sender) else { return [] }
        onTargeted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        hasFiles(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        onTargeted(false)
        onDrop(urls)
        return true
    }
}
