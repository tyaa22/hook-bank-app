import Foundation
import NaturalLanguage

class NLSearchService {
    static let shared = NLSearchService()
    
    private let embedding: NLEmbedding?
    
    private init() {
        // Load the English sentence embedding model
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }
    
    /// Calculates semantic similarity between a query and an activity's description/detail.
    /// Returns a distance (lower distance means more similar, 0 is exact match).
    /// If embedding fails, returns a large distance.
    func distance(for query: String, against text: String) -> Double {
        guard let embedding = embedding else {
            return 2.0 // Max distance fallback
        }
        
        let distance = embedding.distance(between: query, and: text)
        return distance
    }
    
    /// Searches activities semantically.
    func search(query: String, activities: [Activity]) -> [Activity] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return activities
        }
        
        // We will match against a combination of name and description
        let scoredActivities = activities.map { activity -> (Activity, Double) in
            let textToMatch = "\(activity.name). \(activity.activityDescription). Goal: \(activity.goal). Rules: \(activity.howToPlay). Properties: \(activity.property)"
            let distance = self.distance(for: query, against: textToMatch)
            return (activity, distance)
        }
        
        // Filter out highly dissimilar ones (distance > 1.2 is usually quite different,
        // but for a small dummy dataset, we might just sort them)
        let filteredAndSorted = scoredActivities
            .filter { $0.1 < 1.2 } // Adjust threshold as needed
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
        
        // If semantic filtering is too strict for dummy data, fallback to basic sort
        if filteredAndSorted.isEmpty && !activities.isEmpty {
             return scoredActivities.sorted { $0.1 < $1.1 }.map { $0.0 }
        }
        
        return filteredAndSorted
    }
}
