import SwiftUI
import SwiftData

struct ActivitySearchView: View {
    // SwiftData drives the source of truth — sorted alphabetically
    @Query(sort: \Activity.name) private var activities: [Activity]
    @StateObject private var viewModel = ActivitySearchViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    emptyStateView
                } else {
                    List(viewModel.filteredActivities) { activity in
                        NavigationLink(destination: ActivityDetailView(activity: activity)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(activity.name)
                                    .font(.headline)



                                Text(activity.activityDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Activities")
            .searchable(text: $viewModel.searchText, prompt: "Search activities…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle("Semantic Search", isOn: $viewModel.useSemanticSearch)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                }
            }
            // Feed SwiftData changes into the ViewModel
            .onAppear {
                viewModel.updateActivities(activities)
            }
            .onChange(of: activities) { _, newActivities in
                viewModel.updateActivities(newActivities)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No Activities Yet")
                    .font(.title3.weight(.semibold))
                Text("Go to the PDF Importer tab, select a PDF,\nand tap \"Import Activities with AI\".")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ActivitySearchView()
        .modelContainer(for: Activity.self, inMemory: true)
}
