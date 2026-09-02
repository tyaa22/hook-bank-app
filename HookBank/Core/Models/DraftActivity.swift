import Foundation
import SwiftData

/// Represents a Draft of a Hook activity that hasn't been saved yet.
@Model
public final class DraftActivity: Identifiable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var minParticipants: Int
    public var maxParticipants: Int
    public var goal: String
    public var howToPlay: String
    public var possibleProperties: [String]
    public var lastUpdated: Date
    
    public init(
        id: UUID = UUID(),
        name: String = "",
        minParticipants: Int = 1,
        maxParticipants: Int = 10,
        goal: String = "",
        howToPlay: String = "",
        possibleProperties: [String] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.minParticipants = minParticipants
        self.maxParticipants = maxParticipants
        self.goal = goal
        self.howToPlay = howToPlay
        self.possibleProperties = possibleProperties
        self.lastUpdated = lastUpdated
    }
}
