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
                    description: "Nama atau judul dari hook activity (misal: 'Icebreaker Bingo', 'Two Truths and a Lie'). Perbaiki typo atau artefak PDF jika ada."
                ),
                "goal": Schema.string(
                    description: "Goal / tujuan hook activity untuk menaikkan fokus dan keterlibatan learners sebelum sesi pembelajaran dimulai."
                ),
                "howToPlay": Schema.string(
                    description: "Langkah-langkah instruksi yang jelas dan detail tentang How to play / cara memainkan aktivitas ini di kelas."
                ),
                "property": Schema.array(
                    items: Schema.string(description: "Nama perlengkapan / alat / bahan yang dibutuhkan"),
                    description: "Daftar perlengkapan, alat, atau bahan yang dibutuhkan (contoh: ['Kartu Bingo', 'Spidol', 'Kertas']). Jika tidak butuh alat, berikan array kosong atau ['-']."
                ),
                "participant": Schema.string(
                    description: "Jumlah atau kategori peserta / participant (contoh: '10-20 person', '4-6 person (per team)', 'Seluruh kelas'). Jika tidak ditemukan, isi dengan '-'."
                )
            ]
        )
        
        return Schema.object(
            properties: [
                "activities": Schema.array(
                    items: itemSchema,
                    description: "Daftar seluruh aktivitas hook yang berhasil diidentifikasi dari halaman dokumen."
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
                print("⚠️ [GeminiAIService] Failed extracting page \(currentPage): \(error.localizedDescription)")
            }
        }
        
        guard !allActivities.isEmpty else {
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
        Anda adalah asisten cerdas untuk educator/guru yang bertugas mengekstrak aktivitas pemantik (Hook Activity / Icebreaker / Opening Activity) dari materi/dokumen PDF untuk meningkatkan fokus siswa/learners sebelum pembelajaran dimulai.
        
        Tugas Anda:
        Analisis teks halaman PDF berikut dan ekstrak setiap hook activity yang ada menjadi format JSON terstruktur dengan parameter:
        1. 'name': Nama/judul aktivitas. Perbaiki typo/kesalahan ekstraksi huruf ganda atau angka pengganti huruf (misal: "MMoorrnniinngg" -> "Morning").
        2. 'goal': Tujuan aktivitas dalam meningkatkan keterlibatan, pemikiran kritis, atau fokus learners sebelum materi inti dimulai.
        3. 'howToPlay': Instruksi langkah demi langkah cara memainkan aktivitas ini secara jelas dan runtut.
        4. 'property': Daftar perlengkapan/alat/bahan (array of string). Jika tidak memerlukan alat, kembalikan [] atau ["-"].
        5. 'participant': Jumlah peserta/ukuran kelompok yang disarankan (contoh: "10-20 person", "4-6 person (per team)", "Seluruh kelas"). Jika tidak disebutkan, isi dengan "-".
        
        Jika halaman ini tidak memuat aktivitas sama sekali, kembalikan objek JSON dengan 'activities': [].
        """
        
        let generativeModel = firebaseAI.generativeModel(
            modelName: modelName,
            generationConfig: generationConfig,
            systemInstruction: ModelContent(role: "system", parts: [systemPrompt])
        )
        
        let prompt = "Halaman PDF yang diekstrak:\n\n\(pageText)"
        
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
