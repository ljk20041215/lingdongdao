import SwiftUI

/// 文件架满时的水平抖动（spec 错误处理表）。trigger 整数 +1 触发一次。
struct ShakeEffect: GeometryEffect {
    var trigger: CGFloat

    var animatableData: CGFloat {
        get { trigger }
        set { trigger = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 8 * sin(trigger * .pi * 4), y: 0))
    }
}
