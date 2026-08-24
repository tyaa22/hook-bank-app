import Foundation
import SwiftData

@MainActor
class ActivityImportService {
    static let shared = ActivityImportService()
    
    private let llmService: FoundationModelsService
    
    init(llmService: FoundationModelsService = .shared) {
        self.llmService = llmService
    }
    
    /// Query the LLM to structure already extracted raw text pages into Activity models, and insert into SwiftData.
    func importActivities(
        from pages: [String],
        modelContext: ModelContext,
        progress: @escaping (Int, Int) -> Void
    ) async throws -> Int {
        let activities = try await llmService.extractActivities(from: pages, progress: progress)
        
        for activity in activities {
            modelContext.insert(activity)
        }
        try modelContext.save()
        
        return activities.count
    }
}
