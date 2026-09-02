import Foundation
import FirebaseCore
import FirebaseAILogic

public protocol LLMActivityExtracting: Sendable {
    func extractActivities(from pages: [String], progress: @escaping @Sendable (Int, Int) -> Void) async throws -> [Activity]
}

public final class GeminiAIService: LLMActivityExtracting, @unchecked Sendable {
    public static let shared = GeminiAIService()
    
    /// Candidate models in order of priority. If a model encounters token limit / quota / busy, it automatically falls back to the next one.
    public let modelCandidates: [String] = [
        "gemini-3.5-flash",
        "gemini-3.5-flash-lite"
    ]
    
    private let firebaseAI: FirebaseAI
    
    public init(firebaseAI: FirebaseAI = .firebaseAI()) {
        self.firebaseAI = firebaseAI
    }
    
    // MARK: - Errors
    public enum GeminiError: LocalizedError {
        case emptyPages
        case noActivitiesFound
        case allModelsFailed(lastError: String)
        
        public var errorDescription: String? {
            switch self {
            case .emptyPages:
                return "The document does not contain any readable text pages."
            case .noActivitiesFound:
                return "No hook activities were found in the document. Please ensure the PDF contains activity descriptions."
            case .allModelsFailed(let lastError):
                return "Failed to process activities across available Gemini models: \(lastError)"
            }
        }
    }
    
    // MARK: - Codable Intermediate Structures
    private struct ExtractionResponse: Codable {
        let activities: [ExtractedActivityItem]?
    }
    
    private struct ExtractedActivityItem: Codable {
        let name: String?
        let goal: String?
        let howToPlay: String?
        let property: [String]?
        let singleProperty: String?
        let participant: String?
        let participants: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case goal
            case howToPlay
            case property
            case singleProperty = "properties"
            case participant
            case participants
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.goal = try container.decodeIfPresent(String.self, forKey: .goal)
            self.howToPlay = try container.decodeIfPresent(String.self, forKey: .howToPlay)
            self.participant = try container.decodeIfPresent(String.self, forKey: .participant)
            self.participants = try container.decodeIfPresent(String.self, forKey: .participants)
            
            // Handle property as either [String] or String
            if let stringArray = try? container.decodeIfPresent([String].self, forKey: .property) {
                self.property = stringArray
                self.singleProperty = nil
            } else if let singleStr = try? container.decodeIfPresent(String.self, forKey: .property) {
                self.property = [singleStr]
                self.singleProperty = singleStr
            } else if let singleStr = try? container.decodeIfPresent(String.self, forKey: .singleProperty) {
                self.property = [singleStr]
                self.singleProperty = singleStr
            } else if let stringArray = try? container.decodeIfPresent([String].self, forKey: .singleProperty) {
                self.property = stringArray
                self.singleProperty = nil
            } else {
                self.property = nil
                self.singleProperty = nil
            }
        }
    }
    
    // MARK: - Structured Schema
    private var activitySchema: Schema {
        let itemSchema = Schema.object(
            properties: [
                "name": Schema.string(
                    description: "Name or title of the hook activity (example: 'Icebreaker Bingu', 'Two Truths and a Lie'). Fix any typo or PDF artefact if there is any."
                ),
                "goal": Schema.string(
                    description: "Goal or purpose of the hook activity is to increase focus and learners involvement before learning session start."
                ),
                "howToPlay": Schema.string(
                    description: "Clear and detailed step-by-step instruction on how to play this activity in the class."
                ),
                "property": Schema.array(
                    items: Schema.string(description: "Name of required equipment, tools, or materials"),
                    description: "List of required equipment, tools, or materials (example: ['Bingo Card', 'Marker', 'Paper']). If don't need any tools, provide an empty array or ['-']."
                ),
                "participant": Schema.string(
                    description: "Total participant (example: '10-20', '4-6'). If not found, fill it with '-'."
                )
            ]
        )
        
        return Schema.object(
            properties: [
                "activities": Schema.array(
                    items: itemSchema,
                    description: "List of all hook activities successfully identified from the document page."
                )
            ]
        )
    }
    
    // MARK: - Main Extraction Method
    public func extractActivities(
        from pages: [String],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [Activity] {
        guard !pages.isEmpty else {
            throw GeminiError.emptyPages
        }
        
        var allActivities: [Activity] = []
        let totalPages = pages.count
        var lastPageError: Error?
        
        for (index, pageText) in pages.enumerated() {
            let currentPage = index + 1
            progress(currentPage, totalPages)
            
            let trimmedText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { continue }
            
            // Extract activities from this page using candidate models with automatic fallback
            do {
                let pageActivities = try await extractFromSinglePageWithFallback(pageText: trimmedText, pageNumber: currentPage)
                allActivities.append(contentsOf: pageActivities)
            } catch {
                lastPageError = error
                print("⚠️ [GeminiAIService] Failed extracting page \(currentPage): \(error.localizedDescription)")
            }
        }
        
        guard !allActivities.isEmpty else {
            if let error = lastPageError {
                throw error
            }
            throw GeminiError.noActivitiesFound
        }
        
        return allActivities
    }
    
    // MARK: - Page Extraction with Model Fallback
    private func extractFromSinglePageWithFallback(
        pageText: String,
        pageNumber: Int
    ) async throws -> [Activity] {
        var lastError: Error?
        
        for (idx, modelName) in modelCandidates.enumerated() {
            do {
                print("🤖 [GeminiAIService] Trying model '\(modelName)' on page \(pageNumber)...")
                let activities = try await requestGeneration(modelName: modelName, pageText: pageText)
                if !activities.isEmpty {
                    print("✅ [GeminiAIService] Successfully extracted \(activities.count) activities using '\(modelName)' on page \(pageNumber)")
                    return activities
                }
                // If model returned empty JSON array, we can return empty
                return []
            } catch {
                lastError = error
                print("⚠️ [GeminiAIService] Model '\(modelName)' failed on page \(pageNumber): \(error.localizedDescription)")
                
                // If there are more models available in the fallback list, switch to the next model
                if idx < modelCandidates.count - 1 {
                    let nextModel = modelCandidates[idx + 1]
                    print("🔄 [GeminiAIService] Automatically switching to fallback model '\(nextModel)'...")
                }
            }
        }
        
        throw GeminiError.allModelsFailed(lastError: lastError?.localizedDescription ?? "Unknown error")
    }
    
    // MARK: - Request Generation
    private func requestGeneration(
        modelName: String,
        pageText: String
    ) async throws -> [Activity] {
        let generationConfig = GenerationConfig(
            temperature: 0.2,
            responseMIMEType: "application/json",
            responseSchema: activitySchema
        )
        
        let systemPrompt = """
        You are an intelligent assistant for educators, tasked with extracting "hook activities" (icebreakers or opening activities) from PDF materials or documents to boost student focus before the lesson begins.
        
        Important language requirement:
        1. The PDF may be written in English, Indonesian, or a mixture of both.
        2. Always return the output entirely in English, regardless of the language used in the PDF.
        3. If the source content is in Indonesian, translate the relevant activity information into clear, natural English while preserving its original meaning.
        4. Do not include Indonesian text in the output unless it is a proper name, title, specific term, or other text that should reasonably remain unchanged.
        5. Do not invent or add information that is not present or reasonably implied by the source.
                
        Your task:
        Analyze the text from the provided PDF page and extract any hook activities into a structured JSON format using the following parameters:
        1. 'name': The name or title of the activity. Correct any typos or extraction errors, such as repeated characters or numbers replacing letters (e.g., "MMoorrnniinngg" -> "Morning").
        2. 'goal': The purpose of the activity in terms of enhancing learner engagement, critical thinking, or focus before the core material begins.
        3. 'howToPlay': Clear, sequential, step-by-step instructions on how to conduct the activity.
        4. 'property': A list of required equipment, tools, or materials (array of strings). If no tools are needed, return [] or ["-"].
        5. 'participant': The recommended number of participants or group size (e.g., "10-20 people", "4-6 people (per team)", "Entire class"). If not specified, use "-".
                
        If the page contains no activities, return a JSON object with 'activities': [].
        """
        
        let generativeModel = firebaseAI.generativeModel(
            modelName: modelName,
            generationConfig: generationConfig,
            systemInstruction: ModelContent(role: "system", parts: [systemPrompt])
        )
        
        let prompt = "Extracted PDF Page:\n\n\(pageText)"
        
        let response = try await generativeModel.generateContent(prompt)
        
        guard let text = response.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return []
        }
        
        return parseResponseJSON(text)
    }
    
    // MARK: - JSON Parser
    private func parseResponseJSON(_ jsonString: String) -> [Activity] {
        // Clean markdown code blocks if present (```json ... ```)
        var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: .utf8) else {
            return []
        }
        
        let decoder = JSONDecoder()
        
        // Attempt decoding as ExtractionResponse { "activities": [...] }
        if let result = try? decoder.decode(ExtractionResponse.self, from: data),
           let items = result.activities {
            return mapItemsToActivities(items)
        }
        
        // Attempt decoding directly as [ExtractedActivityItem]
        if let directArray = try? decoder.decode([ExtractedActivityItem].self, from: data) {
            return mapItemsToActivities(directArray)
        }
        
        // Attempt decoding single item
        if let singleItem = try? decoder.decode(ExtractedActivityItem.self, from: data) {
            return mapItemsToActivities([singleItem])
        }
        
        return []
    }
    
    private func mapItemsToActivities(_ items: [ExtractedActivityItem]) -> [Activity] {
        return items.compactMap { item in
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            
            let goal = item.goal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
            let howToPlay = item.howToPlay?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-"
            let participant = item.participant ?? item.participants ?? "-"
            
            var properties: [String] = []
            if let props = item.property {
                properties = props.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "-" }
            }
            if properties.isEmpty, let single = item.singleProperty?.trimmingCharacters(in: .whitespacesAndNewlines), !single.isEmpty, single != "-" {
                properties = [single]
            }
            
            return Activity(
                name: name,
                participants: participant.isEmpty ? "-" : participant,
                goal: goal.isEmpty ? "-" : goal,
                howToPlay: howToPlay.isEmpty ? "-" : howToPlay,
                possibleProperties: properties
            )
        }
    }
}
