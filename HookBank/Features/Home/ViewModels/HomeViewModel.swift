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

    /// Handle to the in-flight Gemini extraction, so it can be stopped if the user closes the
    /// import sheet before it finishes — otherwise it's an unstructured `Task`, unrelated to any
    /// view's lifetime, and keeps running (and can still insert results) after the sheet is gone.
    private var analyzeTask: Task<Void, Never>?

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

        analyzeTask = Task {
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

                // The sheet may have been closed (cancelling this task) while a page's network
                // call was already in flight and finished anyway — don't insert results from a
                // run the user asked to stop.
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    for activity in newActivities.reversed() {
                        context.insert(activity)
                    }
                    self.isImporting = false
                    self.extractedPages = []
                    onComplete()
                }
            } catch is CancellationError {
                // Expected when the sheet is closed mid-analysis; cancelAnalysis() already reset
                // isImporting, so there's nothing to surface as an error here.
            } catch {
                await MainActor.run {
                    self.importError = error.localizedDescription
                    self.isImporting = false
                }
            }
        }
    }

    /// Stops any in-flight Gemini extraction. Safe to call even when nothing is running.
    ///
    /// Cancelling `analyzeTask` alone only sets a flag — `extractActivities` has to actually check
    /// it to stop making further Gemini requests, which it does. Requests already in flight when
    /// this is called may still complete on the server; this only guarantees their results won't
    /// be used (see the `Task.isCancelled` check above) and that no further pages are requested.
    func cancelAnalysis() {
        analyzeTask?.cancel()
        analyzeTask = nil
        isImporting = false
    }
}

