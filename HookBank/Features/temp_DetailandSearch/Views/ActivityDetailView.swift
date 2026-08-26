import SwiftUI
import Core

struct ActivityDetailView: View {
    let activity: Activity
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if !activity.possibleProperties.isEmpty {
                        Label(activity.possibleProperties.joined(separator: ", "), systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                Divider()
                
                // Goal
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(activity.goal)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
                // How to Play
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Play")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(activity.howToPlay)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                
                // Property (if available)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Property / Requirements")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(activity.possibleProperties.isEmpty ? "-" : activity.possibleProperties.joined(separator: ", "))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Activity Info")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
