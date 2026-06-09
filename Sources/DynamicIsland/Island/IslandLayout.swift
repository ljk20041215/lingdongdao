import Foundation

/// 窗口与面板的尺寸常量/换算。第一版不做设置界面，参数全部用常量（spec YAGNI）。
enum IslandLayout {
    /// 收起态每侧露出的"翼"宽度（迷你封面 / 波形）
    static let chipWidth: CGFloat = 56
    /// 展开面板高度（宽度与收起态同宽，见 expandedWindowRect：收起/展开只变高不变宽）
    static let expandedHeight: CGFloat = 300

    static func collapsedWindowRect(notch: CGRect) -> CGRect {
        CGRect(x: notch.minX - chipWidth,
               y: notch.minY,
               width: notch.width + chipWidth * 2,
               height: notch.height)
    }

    static func expandedWindowRect(notch: CGRect) -> CGRect {
        // 与收起态同宽（刘海+两翼）、同 x：收起/展开是纯高度变化，无横向跳变（根治"收起忽然变宽/抖动"）
        let width = notch.width + chipWidth * 2
        return CGRect(x: notch.minX - chipWidth,
                      y: notch.maxY - expandedHeight,
                      width: width,
                      height: expandedHeight)
    }

    static func windowRect(for state: IslandState, notch: CGRect) -> CGRect {
        switch state {
        case .collapsed: return collapsedWindowRect(notch: notch)
        case .expanded, .dropTarget: return expandedWindowRect(notch: notch)
        }
    }
}
