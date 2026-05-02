import SwiftUI

struct RatingBadge: View {
    let rating: Int

    var body: some View {
        Text("\(rating)/10")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch rating {
        case 8...10: return FloTimeTheme.primary
        case 5...7: return FloTimeTheme.secondary
        default: return Color.gray.opacity(0.7)
        }
    }
}
