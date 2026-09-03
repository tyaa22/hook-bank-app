import Foundation
import SwiftData

/// Represents a Draft of a Hook activity that hasn't been saved yet.
@Model
public final class DraftActivity: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var participants: Int
    public var duration: String
    public var categories: [String]
    public var goal: String
    public var howToPlay: String
    public var possibleProperties: [String]
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        name: String = "",
        participants: Int = 10,
        duration: String = "-",
        categories: [String] = [],
        goal: String = "",
        howToPlay: String = "",
        possibleProperties: [String] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.participants = participants
        self.duration = duration
        self.categories = categories
        self.goal = goal
        self.howToPlay = howToPlay
        self.possibleProperties = possibleProperties
        self.lastUpdated = lastUpdated
    }
}
