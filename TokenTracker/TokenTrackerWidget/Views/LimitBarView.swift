import SwiftUI

struct LimitBarView: View {
    let label: String
    let percent: Double   // 0.0 to 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.8))
                        .frame(width: geo.size.width * min(percent, 1.0))
                }
            }
            .frame(height: 3)
        }
    }
}
