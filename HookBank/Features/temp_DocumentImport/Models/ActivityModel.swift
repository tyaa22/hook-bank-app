import Foundation
import SwiftData

@Model
final class Activity {
    @Attribute(.unique) var id: UUID
    var name: String
    var activityDescription: String // Renamed representation of 'description' to avoid description class clash
    var goal: String
    var howToPlay: String
    var property: String

    init(
        id: UUID = UUID(),
        name: String,
        activityDescription: String,
        goal: String,
        howToPlay: String,
        property: String
    ) {
        self.id = id
        self.name = name
        self.activityDescription = activityDescription
        self.goal = goal
        self.howToPlay = howToPlay
        self.property = property
    }
}
