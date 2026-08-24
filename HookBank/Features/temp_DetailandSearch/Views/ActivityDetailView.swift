import SwiftUI

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
                    
                    if activity.property != "-" {
                        Label(activity.property, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                Divider()
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(activity.activityDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                
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
                    
                    Text(activity.property)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Activity Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
