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

    /// How many pages are sent to Gemini at once. Processing pages one at a time made import time
    /// scale linearly with page count — a 20-page PDF meant 20 sequential network round-trips.
    /// Running several concurrently cuts wall-clock time roughly by this factor without increasing
    /// the number of API calls. Kept modest to stay clear of per-project rate limits.
    private let maxConcurrentPages = 4
    
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
    
    /// Plain, `Sendable` mirror of `Activity`'s fields. `Activity` is a SwiftData `@Model` and isn't
    /// Sendable, so it can't cross the concurrency boundary of a `TaskGroup` child task — this type
    /// is what actually flows between pages processed in parallel; the real `Activity` objects are
    /// only constructed back on the caller's side once every page has finished.
    private struct ExtractedActivityData: Sendable {
        let name: String
        let participants: String
        let goal: String
        let howToPlay: String
        let possibleProperties: [String]
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

    /// Extracts activities from every page, up to `maxConcurrentPages` at a time, instead of one
    /// request after another. `progress` now reports how many pages have *finished* (not which page
    /// is "current") — with concurrent requests, page 5 can complete before page 3 does — and
    /// results are reassembled in original page order regardless of completion order, so the
    /// output is identical to the old sequential version, just faster to produce.
    public func extractActivities(
        from pages: [String],
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> [Activity] {
        guard !pages.isEmpty else {
            throw GeminiError.emptyPages
        }

        let totalPages = pages.count
        let pendingPages: [(pageNumber: Int, text: String)] = pages.enumerated().compactMap { index, pageText in
            let trimmed = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : (index + 1, trimmed)
        }

        var resultsByPage: [Int: [ExtractedActivityData]] = [:]
        var lastPageError: Error?
        var completedCount = 0

        await withTaskGroup(of: (pageNumber: Int, outcome: Result<[ExtractedActivityData], Error>).self) { group in
            var nextPending = pendingPages[...]

            func startNextTask() {
                guard let next = nextPending.first else { return }
                nextPending = nextPending.dropFirst()
                group.addTask {
                    do {
                        let data = try await self.extractFromSinglePageWithFallback(pageText: next.text, pageNumber: next.pageNumber)
                        return (next.pageNumber, .success(data))
                    } catch {
                        return (next.pageNumber, .failure(error))
                    }
                }
            }

            for _ in 0..<min(maxConcurrentPages, pendingPages.count) {
                startNextTask()
            }

            while let (pageNumber, outcome) = await group.next() {
                completedCount += 1
                progress(completedCount, totalPages)

                switch outcome {
                case .success(let data):
                    resultsByPage[pageNumber] = data
                case .failure(let error):
                    lastPageError = error
                    print("⚠️ [GeminiAIService] Failed extracting page \(pageNumber): \(error.localizedDescription)")
                }

                // The caller (e.g. the import sheet being closed) cancelled us: stop requesting
                // pages that haven't started yet, and cancel whatever's still in flight rather
                // than waiting out its full network round-trip before this function can return.
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }

                startNextTask()
            }
        }

        // `Activity` (SwiftData) is only ever constructed here, back on the caller's context —
        // never inside the concurrent child tasks above.
        let allActivities = resultsByPage.keys.sorted().flatMap { pageNumber in
            (resultsByPage[pageNumber] ?? []).map { data in
                Activity(
                    name: data.name,
                    participants: data.participants,
                    goal: data.goal,
                    howToPlay: data.howToPlay,
                    possibleProperties: data.possibleProperties
                )
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
    ) async throws -> [ExtractedActivityData] {
        // A task queued behind `maxConcurrentPages` others can sit waiting long enough for the
        // caller to cancel before it ever starts — this stops it before it makes a network call.
        try Task.checkCancellation()

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
    ) async throws -> [ExtractedActivityData] {
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
    private func parseResponseJSON(_ jsonString: String) -> [ExtractedActivityData] {
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
            return mapItemsToData(items)
        }

        // Attempt decoding directly as [ExtractedActivityItem]
        if let directArray = try? decoder.decode([ExtractedActivityItem].self, from: data) {
            return mapItemsToData(directArray)
        }

        // Attempt decoding single item
        if let singleItem = try? decoder.decode(ExtractedActivityItem.self, from: data) {
            return mapItemsToData([singleItem])
        }

        return []
    }

    private func mapItemsToData(_ items: [ExtractedActivityItem]) -> [ExtractedActivityData] {
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

            return ExtractedActivityData(
                name: name,
                participants: participant.isEmpty ? "-" : participant,
                goal: goal.isEmpty ? "-" : goal,
                howToPlay: howToPlay.isEmpty ? "-" : howToPlay,
                possibleProperties: properties
            )
        }
    }
}
