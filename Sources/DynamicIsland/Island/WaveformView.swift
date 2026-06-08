import SwiftUI

/// 收起态右翼的音频波形：4 根跳动的竖条。
/// 用 phaseAnimator 驱动——它随视图出现就持续循环，不像 .repeatForever 那样
/// 在收起态重新插入时停住（这正是「移走后波形变静态」的根因）。
struct WaveformView: View {
    let isPlaying: Bool

    private let baseHeights: [CGFloat] = [8, 16, 11, 14]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                bar(index: i)
            }
        }
        .frame(height: 18)
    }

    @ViewBuilder
    private func bar(index i: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.green)
            .frame(width: 3, height: baseHeights[i])
        if isPlaying {
            // 两相循环：竖条在 35%↔100% 高度间往复；每根周期略不同，呈自然错落
            shape.phaseAnimator([CGFloat(0.35), 1.0]) { view, scale in
                view.scaleEffect(y: scale, anchor: .center)
            } animation: { _ in
                .easeInOut(duration: 0.38 + Double(i) * 0.07)
            }
        } else {
            // 暂停：定格在低位
            shape.scaleEffect(y: 0.35, anchor: .center)
        }
    }
}
