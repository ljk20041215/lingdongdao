import SwiftUI

/// 底部页点：当前页实心白，其余灰；点哪个回调哪个序号。
struct PageDotsView: View {
    let count: Int
    let current: Int
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.white : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(i) }
            }
        }
    }
}
