import SwiftUI
import SwiftData
import Core

@Observable
public final class HomeViewModel {
    // MARK: - PDF Import state
    var isExtracting: Bool = false
    var isImporting: Bool = false
    var currentPageImporting: Int = 0
    var totalPagesImporting: Int = 0
    var extractedPages: [String] = []
    var importError: String? = nil

    private let extractor: DocumentTextExtracting
    private let llmService: LLMActivityExtracting

    public init(
        extractor: DocumentTextExtracting = PDFTextExtractor(),
        llmService: LLMActivityExtracting = GeminiAIService.shared
    ) {
        self.extractor = extractor
        self.llmService = llmService
    }



    // MARK: - PDF Import

    /// Step 1 — extract raw text from the PDF file.
    func handleFileSelection(url: URL) {
        importError = nil
        isExtracting = true
        extractedPages = []

        Task {
            do {
                let pages = try await extractor.extractText(from: url)
                await MainActor.run {
                    self.extractedPages = pages
                    self.isExtracting = false
                }
            } catch {
                await MainActor.run {
                    self.importError = "Could not read PDF: \(error.localizedDescription)"
                    self.isExtracting = false
                }
            }
        }
    }

    /// Step 2 — send extracted pages to Gemini LLM and add results to the activity list.
    func analyzeWithAI(context: ModelContext, onComplete: @escaping () -> Void) {
        guard !extractedPages.isEmpty else { return }

        isImporting = true
        importError = nil
        currentPageImporting = 0
        totalPagesImporting = extractedPages.count

        Task {
            do {
                let newActivities = try await llmService.extractActivities(
                    from: extractedPages
                ) { [weak self] current, total in
                    guard let self else { return }
                    Task { @MainActor in
                        self.currentPageImporting = current
                        self.totalPagesImporting = total
                    }
                }
                await MainActor.run {
                    for activity in newActivities.reversed() {
                        context.insert(activity)
                    }
                    self.isImporting = false
                    self.extractedPages = []
                    onComplete()
                }
            } catch {
                await MainActor.run {
                    self.importError = error.localizedDescription
                    self.isImporting = false
                }
            }
        }
    }
}

