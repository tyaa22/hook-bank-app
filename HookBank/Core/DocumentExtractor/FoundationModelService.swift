import Foundation
import FoundationModels

// MARK: - @Generable types for structured extraction

/// Represents a single activity extracted from a PDF by the on-device LLM.
@Generable
struct ExtractedActivity {
    @Guide(description: "The activity title — the heading that appears BEFORE the 'Goal:' label. Must be corrected from any doubled-letter or number-substitution artifacts to normal spelling.")
    var name: String

    @Guide(description: "A short general description summarizing what the activity is about. Must be corrected to normal spelling.")
    var description: String

    @Guide(description: "The goal or objective of the activity (often explicitly marked as 'Goal:' in the text). Must be corrected to normal spelling.")
    var goal: String

    @Guide(description: "Step-by-step instructions or rules on how to play/conduct the activity. Must be corrected to normal spelling.")
    var howToPlay: String

    @Guide(description: "Specific properties, parameters, materials, or configuration details of the activity (e.g. 'Materials: name tags, napkin, cards' or group size requirements). If not found or empty, fill with '-'.")
    var property: String
}

/// Top-level wrapper so the model returns all activities in one structured call (bulk support).
@Generable
struct ActivityExtractionResult {
    @Guide(description: "Every distinct activity found in the document. Return an empty array if none are found.")
    var activities: [ExtractedActivity]
}

// MARK: - Service

/// Uses Apple's Foundation Models framework (on-device LLM, iOS 26+) to extract
/// structured Activity data from raw PDF text.
@MainActor
class FoundationModelsService {
    static let shared = FoundationModelsService()
    private init() {}

    // MARK: - Errors

    enum ExtractionError: LocalizedError {
        case modelUnavailable
        case noActivitiesFound

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Apple Intelligence is not available on this device. Please enable Apple Intelligence in Settings → Apple Intelligence & Siri."
            case .noActivitiesFound:
                return "No activities were found in this document. Try a different PDF or check that it contains recognisable activity descriptions."
            }
        }
    }

    // MARK: - Extraction

    /// Processes multiple PDF pages page-by-page sequentially to prevent context window overflow.
    /// Passes the current page index and total page count back via `progress` block.
    func extractActivities(from pages: [String], progress: @escaping (Int, Int) -> Void) async throws -> [Activity] {
        // Guard: model must be available on this device / OS
        guard SystemLanguageModel.default.isAvailable else {
            throw ExtractionError.modelUnavailable
        }

        var allActivities: [Activity] = []
        let totalPages = pages.count

        for (index, pageText) in pages.enumerated() {
            let currentPage = index + 1
            progress(currentPage, totalPages)

            let trimmedText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                continue
            }

            let session = LanguageModelSession()

            let prompt = """
            You are an expert at reading garbled PDF-extracted text and recovering the original content.

            CRITICAL — TEXT ARTIFACTS TO FIX:
            The text below is from ONE page of a PDF and may contain extraction artifacts:
            1. DOUBLED LETTERS: Every letter may be duplicated, e.g., "MMoorrnniinngg" → "Morning", "NNeeiigghhbboouurrss" → "Neighbours".
            2. NUMBER-LETTER SUBSTITUTIONS: Digits may replace letters, e.g., "1" instead of "l", "0" instead of "o". Example: "AAl11l" → "All".

            DOCUMENT STRUCTURE:
            Each activity in the document follows this pattern:
            - LINE 1: The ACTIVITY TITLE (the heading/name, often garbled with doubled letters and number substitutions)
            - "Goal:" line: The goal or objective of the activity.
            - Additional instructions/description outlining how to play.
            - "Materials:" or properties details (if available).

            YOUR TASK:
            For each activity found on this page, extract:
            1. "name": The TITLE from the heading line. Correct all doubled letters and number substitutions to proper English spelling.
            2. "description": A concise overview or summary of the activity.
            3. "goal": The text after "Goal:" corrected to proper spelling.
            4. "howToPlay": The description of steps or rules explaining how to play.
            5. "property": Materials, setup rules, or configurations needed. If not found or empty, you MUST fill it with "-".

            If no activities are found on this page, return an empty list.

            Page text to process:
            \(trimmedText)
            """

            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: ActivityExtractionResult.self
                )

                let extracted = response.content.activities
                let mapped = extracted.map { item in
                    Activity(
                        name: item.name,
                        activityDescription: item.description,
                        goal: item.goal,
                        howToPlay: item.howToPlay,
                        property: item.property.isEmpty ? "-" : item.property
                    )
                }
                allActivities.append(contentsOf: mapped)
            } catch {
                // Log and continue to process other pages rather than failing the entire process
                print("Error extracting activities from page \(currentPage): \(error.localizedDescription)")
            }
        }

        guard !allActivities.isEmpty else {
            throw ExtractionError.noActivitiesFound
        }

        return allActivities
    }
}
