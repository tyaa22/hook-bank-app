import Foundation

struct Post: Identifiable, Codable, Equatable {
    let id: Int
    let title: String
    let body: String
}
