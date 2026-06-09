/// 一次滑动手势的累计水平位移 → 翻页方向（+1 下一页 / -1 上一页 / 0 不翻）。
/// 约定（macOS 自然滚动）：手指左滑 scrollingDeltaX 累计为负 → 下一页。
/// 若实机方向相反（如关闭了自然滚动），把这两个判断的符号对调即可。
enum PageSwipe {
    static func pageDelta(accumulatedX: Double, threshold: Double) -> Int {
        if accumulatedX <= -threshold { return 1 }
        if accumulatedX >= threshold { return -1 }
        return 0
    }
}
