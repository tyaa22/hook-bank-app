import Foundation

/// Represents a Hook activity.
/// This class is designed to be easily adaptable to SwiftData (@Model) in the future.
public class Activity: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var participants: String
    public var goal: String
    public var howToPlay: String
    public var possibleProperties: [String]
    
    public init(
        id: UUID = UUID(),
        name: String,
        participants: String,
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
    
    // Hashable conformance for SwiftUI Lists and Navigation
    public static func == (lhs: Activity, rhs: Activity) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Mock Data
public extension Activity {
    static let mockActivities: [Activity] = [
        Activity(
            name: "Icebreaker Bingo",
            participants: "10-20 person",
            goal: "Help participants learn interesting facts about each other in a relaxed setting.",
            howToPlay: "Give each participant a bingo card with different traits. They must mingle and find people who match each trait to get a bingo.",
            possibleProperties: ["Bingo Cards", "Pens"]
        ),
        Activity(
            name: "Two Truths and a Lie",
            participants: "4-10 person",
            goal: "Encourage sharing and guessing to build rapport quickly.",
            howToPlay: "Each person states three facts about themselves: two true, one false. The rest of the group guesses which one is the lie.",
            possibleProperties: []
        ),
        Activity(
            name: "Human Knot",
            participants: "6-12 person",
            goal: "Build teamwork and problem-solving skills.",
            howToPlay: "Stand in a circle, reach across and grab hands with two different people. Untangle the knot without letting go of hands.",
            possibleProperties: []
        ),
        Activity(
            name: "Marshmallow Challenge",
            participants: "4-6 person (per team)",
            goal: "Foster collaboration and creative thinking under time constraints.",
            howToPlay: "Teams compete to build the tallest free-standing structure out of spaghetti, tape, and string, topped with a marshmallow.",
            possibleProperties: ["Spaghetti", "Tape", "String", "Marshmallows"]
        )
    ]
}
