import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear
                case .loading:
                    ProgressView("Loading Feed...")
                case .loaded(let posts):
                    List(posts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(post.title).font(.headline)
                            Text(post.body).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                case .error(let message):
                    VStack(spacing: 16) {
                        Text(message).foregroundColor(.red).multilineTextAlignment(.center)
                        PrimaryButton(title: "Retry") {
                            Task { await viewModel.loadFeed() }
                        }
                        .padding(.horizontal, 40)
                    }
                }
            }
            .navigationTitle("Feed")
            .task { await viewModel.loadFeed() }
        }
    }
}
