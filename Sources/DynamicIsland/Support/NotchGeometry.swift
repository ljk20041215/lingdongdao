import Foundation

/// 刘海几何信息。纯值类型，便于测试；从 NSScreen 取值的封装见下方扩展。
struct NotchGeometry: Equatable {
    /// 刘海矩形（AppKit 屏幕坐标，原点左下）
    let notchRect: CGRect
    let hasNotch: Bool

    static let fallbackSize = CGSize(width: 184, height: 32)

    static func compute(screenFrame: CGRect,
                        safeTopInset: CGFloat,
                        leftAuxWidth: CGFloat?,
                        rightAuxWidth: CGFloat?) -> NotchGeometry {
        guard safeTopInset > 0, let left = leftAuxWidth, let right = rightAuxWidth else {
            let rect = CGRect(x: screenFrame.midX - fallbackSize.width / 2,
                              y: screenFrame.maxY - fallbackSize.height,
                              width: fallbackSize.width,
                              height: fallbackSize.height)
            return NotchGeometry(notchRect: rect, hasNotch: false)
        }
        let rect = CGRect(x: screenFrame.minX + left,
                          y: screenFrame.maxY - safeTopInset,
                          width: screenFrame.width - left - right,
                          height: safeTopInset)
        return NotchGeometry(notchRect: rect, hasNotch: true)
    }
}

#if canImport(AppKit)
import AppKit

extension NotchGeometry {
    /// 优先选有刘海的内建屏
    static func fromBestScreen() -> NotchGeometry? {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else { return nil }
        return compute(screenFrame: screen.frame,
                       safeTopInset: screen.safeAreaInsets.top,
                       leftAuxWidth: screen.auxiliaryTopLeftArea?.width,
                       rightAuxWidth: screen.auxiliaryTopRightArea?.width)
    }
}
#endif
