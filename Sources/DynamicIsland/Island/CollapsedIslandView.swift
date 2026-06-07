import SwiftUI

struct CollapsedIslandView: View {
    let notchSize: CGSize

    var body: some View {
        Color.black
            .frame(width: notchSize.width, height: notchSize.height)
            .clipShape(.rect(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }
}
