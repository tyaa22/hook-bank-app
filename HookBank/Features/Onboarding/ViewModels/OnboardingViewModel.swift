import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum State {
        case idle, loading, loaded([Post]), error(String)
    }

    @Published private(set) var state: State = .idle
    private let feedService: FeedServiceProtocol

    init(feedService: FeedServiceProtocol = FeedService()) {
        self.feedService = feedService
    }

    func loadFeed() async {
        state = .loading
        do {
            let posts = try await feedService.fetchPosts()
            state = .loaded(posts)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
