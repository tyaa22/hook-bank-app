import SwiftUI
import Core

struct ActivityCard: View {
    let activity: Activity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(activity.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
            }
            
            // Participant quantity
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 12))
                Text(activity.participants)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color("PrimaryAccentColor"))
            .padding(.vertical, 6)
            
            // Description snippet
            Text(activity.goal)
                .font(.system(size: 14))
                .foregroundColor(Color("DescriptionColor"))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.949, green: 0.949, blue: 0.969, opacity: 1.00))
        .cornerRadius(12)
//        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ZStack {
        Color(white: 0.95).ignoresSafeArea()
        ActivityCard(activity: Activity.mockActivities[0])
            .padding()
    }
}
