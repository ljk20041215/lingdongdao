import SwiftUI

/// 收起态右翼的音频波形：4 根跳动的竖条
struct WaveformView: View {
    let isPlaying: Bool
    @State private var animating = false

    private let baseHeights: [CGFloat] = [8, 16, 11, 14]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.green)
                    .frame(width: 3,
                           height: animating ? baseHeights[i] : 5)
                    .animation(
                        isPlaying
                            ? .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.12)
                            : .default,
                        value: animating)
            }
        }
        .frame(height: 18)
        .onAppear { animating = isPlaying }
        .onChange(of: isPlaying) { _, playing in animating = playing }
    }
}
