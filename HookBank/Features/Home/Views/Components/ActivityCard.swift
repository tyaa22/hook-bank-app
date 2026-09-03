import SwiftUI
import Core

struct ActivityCard: View {
    let activity: Activity

    /// Beyond this many category chips, the rest are collapsed into a single "+N" chip so the row
    /// never wraps or pushes the card's height around.
    private let maxVisibleCategories = 2

    private var accentColor: Color { Color("PrimaryAccentColor") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(activity.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(white: 0.75))
            }

            // Ideal participants + duration
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                    Text("\(activity.participants) person")
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(activity.duration)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(accentColor)

            // Description snippet
            Text(activity.goal)
                .font(.system(size: 14))
                .foregroundColor(Color("DescriptionColor"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if !activity.categories.isEmpty {
                categoryChips
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.949, green: 0.949, blue: 0.969, opacity: 1.00))
        .cornerRadius(12)
    }

    private var categoryChips: some View {
        let visible = activity.categories.prefix(maxVisibleCategories)
        let overflowCount = activity.categories.count - visible.count

        return HStack(spacing: 8) {
            ForEach(Array(visible), id: \.self) { category in
                categoryChip(category)
            }
            if overflowCount > 0 {
                categoryChip("+\(overflowCount)")
            }
        }
    }

    private func categoryChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(accentColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color(white: 0.95).ignoresSafeArea()
        ActivityCard(activity: Activity.mockActivities[0])
            .padding()
    }
}
