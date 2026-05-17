import SwiftUI

struct ClaudeLogoView: View {
    var size: CGFloat = 18

    var body: some View {
        Image("ClaudeLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
