import Foundation

/// 窗口与面板的尺寸常量/换算。第一版不做设置界面，参数全部用常量（spec YAGNI）。
enum IslandLayout {
    /// 收起态每侧露出的"翼"宽度（迷你封面 / 波形）
    static let chipWidth: CGFloat = 56
    /// 展开面板尺寸
    static let expandedSize = CGSize(width: 640, height: 220)

    static func collapsedWindowRect(notch: CGRect) -> CGRect {
        CGRect(x: notch.minX - chipWidth,
               y: notch.minY,
               width: notch.width + chipWidth * 2,
               height: notch.height)
    }

    static func expandedWindowRect(notch: CGRect) -> CGRect {
        let width = max(expandedSize.width, notch.width + chipWidth * 2)
        return CGRect(x: notch.midX - width / 2,
                      y: notch.maxY - expandedSize.height,
                      width: width,
                      height: expandedSize.height)
    }

    static func windowRect(for state: IslandState, notch: CGRect) -> CGRect {
        switch state {
        case .collapsed: return collapsedWindowRect(notch: notch)
        case .expanded, .dropTarget: return expandedWindowRect(notch: notch)
        }
    }
}
