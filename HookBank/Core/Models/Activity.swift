import Foundation
import SwiftData

/// Represents a Hook activity.
@Model
public final class Activity: Identifiable, Hashable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var participants: String
    public var goal: String
    public var howToPlay: String
    public var possibleProperties: [String]
    
    public init(
        id: UUID = UUID(),
        name: String,
        participants: String = "-",
        goal: String,
        howToPlay: String,
        possibleProperties: [String] = []
    ) {
        self.id = id
        self.name = name
        self.participants = participants
        self.goal = goal
        self.howToPlay = howToPlay
        self.possibleProperties = possibleProperties
    }
}

// MARK: - Mock Data
public extension Activity {
    static let mockActivities: [Activity] = [
        Activity(
            name: "Icebreaker Bingo",
            participants: "10-20",
            goal: "Help participants learn interesting facts about each other in a relaxed setting.",
            howToPlay: "Give each participant a bingo card with different traits. They must mingle and find people who match each trait to get a bingo.",
            possibleProperties: ["Bingo Cards", "Pens"]
        ),
        Activity(
            name: "Two Truths and a Lie",
            participants: "4-10",
            goal: "Encourage sharing and guessing to build rapport quickly.",
            howToPlay: "Each person states three facts about themselves: two true, one false. The rest of the group guesses which one is the lie.",
            possibleProperties: []
        ),
        Activity(
            name: "Human Knot",
            participants: "6-12",
            goal: "Build teamwork and problem-solving skills.",
            howToPlay: "Stand in a circle, reach across and grab hands with two different people. Untangle the knot without letting go of hands.",
            possibleProperties: []
        ),
        Activity(
            name: "Marshmallow Challenge",
            participants: "4-6",
            goal: "Foster collaboration and creative thinking under time constraints.",
            howToPlay: "Teams compete to build the tallest free-standing structure out of spaghetti, tape, and string, topped with a marshmallow.",
            possibleProperties: ["Spaghetti", "Tape", "String", "Marshmallows"]
        )
    ]
}
