import Foundation
import SwiftData

/// The 7 fixed categories a hook activity can be classified into. An activity may belong to more
/// than one when it genuinely fits multiple purposes.
public enum ActivityCategory: String, CaseIterable, Codable, Sendable {
    case connection = "Connection"
    case energizing = "Energizing"
    case leadership = "Leadership"
    case justFun = "Just Fun"
    case reflection = "Reflection"
    case communication = "Communication"
    case criticalThinking = "Critical Thinking"

    /// A representative SF Symbol for showing this category in lists/filters.
    public var symbolName: String {
        switch self {
        case .connection: "figure.2.arms.open"
        case .energizing: "bolt.fill"
        case .leadership: "flag.fill"
        case .justFun: "party.popper.fill"
        case .reflection: "arrow.triangle.2.circlepath"
        case .communication: "bubble.left.and.bubble.right.fill"
        case .criticalThinking: "brain.head.profile"
        }
    }
}

/// Represents a Hook activity.
@Model
public final class Activity: Identifiable, Hashable {
    @Attribute(.unique) public var id: UUID
    public var name: String
    /// Ideal number of participants for one facilitator/educator to run this activity — not a
    /// min-max range. A larger group is still possible, it just needs additional facilitators.
    public var participants: Int
    /// How long the activity takes, e.g. "10 minutes" or "10-20 minutes".
    public var duration: String
    /// One or more of the 7 fixed `ActivityCategory` values that fit this activity.
    public var categories: [String]
    public var goal: String
    public var howToPlay: String
    public var possibleProperties: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        participants: Int = 10,
        duration: String = "-",
        categories: [String] = [],
        goal: String,
        howToPlay: String,
        possibleProperties: [String] = []
    ) {
        self.id = id
        self.name = name
        self.participants = participants
        self.duration = duration
        self.categories = categories
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
            participants: 20,
            duration: "10-20 minutes",
            categories: [ActivityCategory.connection.rawValue, ActivityCategory.justFun.rawValue],
            goal: "Help participants learn interesting facts about each other in a relaxed setting.",
            howToPlay: "Give each participant a bingo card with different traits. They must mingle and find people who match each trait to get a bingo.",
            possibleProperties: ["Bingo Cards", "Pens"]
        ),
        Activity(
            name: "Two Truths and a Lie",
            participants: 10,
            duration: "10 minutes",
            categories: [ActivityCategory.communication.rawValue],
            goal: "Encourage sharing and guessing to build rapport quickly.",
            howToPlay: "Each person states three facts about themselves: two true, one false. The rest of the group guesses which one is the lie.",
            possibleProperties: []
        ),
        Activity(
            name: "Human Knot",
            participants: 12,
            duration: "15 minutes",
            categories: [ActivityCategory.leadership.rawValue, ActivityCategory.criticalThinking.rawValue, ActivityCategory.energizing.rawValue],
            goal: "Build teamwork and problem-solving skills.",
            howToPlay: "Stand in a circle, reach across and grab hands with two different people. Untangle the knot without letting go of hands.",
            possibleProperties: []
        ),
        Activity(
            name: "Marshmallow Challenge",
            participants: 6,
            duration: "20-30 minutes",
            categories: [ActivityCategory.criticalThinking.rawValue, ActivityCategory.leadership.rawValue],
            goal: "Foster collaboration and creative thinking under time constraints.",
            howToPlay: "Teams compete to build the tallest free-standing structure out of spaghetti, tape, and string, topped with a marshmallow.",
            possibleProperties: ["Spaghetti", "Tape", "String", "Marshmallows"]
        )
    ]
}
