import Foundation
import Combine

@MainActor
class ActivitySearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredActivities: [Activity] = []
    @Published var useSemanticSearch: Bool = true

    private var allActivities: [Activity] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Re-run search whenever query text or mode changes
        $searchText
            .combineLatest($useSemanticSearch)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query, semantic in
                self?.performSearch(query: query, semantic: semantic)
            }
            .store(in: &cancellables)
    }

    /// Called by the view whenever the @Query result changes.
    func updateActivities(_ activities: [Activity]) {
        allActivities = activities
        performSearch(query: searchText, semantic: useSemanticSearch)
    }

    private func performSearch(query: String, semantic: Bool) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            filteredActivities = allActivities
            return
        }

        if semantic {
            filteredActivities = NLSearchService.shared.search(query: trimmed, activities: allActivities)
        } else {
            filteredActivities = allActivities.filter { activity in
                activity.name.localizedCaseInsensitiveContains(trimmed) ||
                activity.activityDescription.localizedCaseInsensitiveContains(trimmed) ||
                activity.goal.localizedCaseInsensitiveContains(trimmed) ||
                activity.howToPlay.localizedCaseInsensitiveContains(trimmed) ||
                activity.property.localizedCaseInsensitiveContains(trimmed)
            }
        }
    }
}
