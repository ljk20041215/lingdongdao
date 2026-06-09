import AppKit

/// 监听本 app 的两指水平滚动（即在灵动岛面板上的滚动）：按手势累计 scrollingDeltaX，
/// 手势结束时用 PageSwipe 判定是否翻页。本地监听不拦截点击；忽略 momentum 惯性阶段。
final class SwipeMonitor {
    private var monitor: Any?
    private var accumulated: Double = 0
    private var tracking = false
    private let threshold: Double
    private let onPage: (Int) -> Void

    init(threshold: Double = 40, onPage: @escaping (Int) -> Void) {
        self.threshold = threshold
        self.onPage = onPage
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        accumulated = 0
        tracking = false
    }

    private func handle(_ event: NSEvent) {
        if event.phase.contains(.began) {
            tracking = true
            accumulated = 0
        } else if event.phase.contains(.changed) {
            if tracking { accumulated += Double(event.scrollingDeltaX) }
        } else if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            guard tracking else { return }
            tracking = false
            let delta = PageSwipe.pageDelta(accumulatedX: accumulated, threshold: threshold)
            accumulated = 0
            if delta != 0 { onPage(delta) }
        }
        // momentum（惯性）阶段 event.phase 为空 → 落到这里被忽略，避免一甩翻多页
    }
}
