import Foundation

protocol FeedServiceProtocol: Sendable {
    func fetchPosts() async throws -> [Post]
}
