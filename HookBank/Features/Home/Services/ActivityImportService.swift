import Foundation
import SwiftData
import Core

@MainActor
class ActivityImportService {
    static let shared = ActivityImportService()
    
    private let llmService: LLMActivityExtracting

    init(llmService: LLMActivityExtracting? = nil) {
        self.llmService = llmService ?? GeminiAIService.shared
    }

    /// Query Gemini LLM to structure already extracted raw text pages into Activity models, and insert into SwiftData.
    func importActivities(
        from pages: [String],
        modelContext: ModelContext,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> Int {
        let activities = try await llmService.extractActivities(from: pages, progress: progress)
        
        let descriptor = FetchDescriptor<Activity>()
        let existingActivities = (try? modelContext.fetch(descriptor)) ?? []
        var existingNames = Set(
            existingActivities.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )

        var insertedCount = 0
        for activity in activities {
            let normalizedName = activity.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalizedName.isEmpty else { continue }

            if !existingNames.contains(normalizedName) {
                modelContext.insert(activity)
                existingNames.insert(normalizedName)
                insertedCount += 1
            }
        }
        try modelContext.save()
        
        return insertedCount
    }
}

