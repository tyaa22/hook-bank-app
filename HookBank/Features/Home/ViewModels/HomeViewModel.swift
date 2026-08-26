import SwiftUI
import Core

@Observable
public final class HomeViewModel {
    public var activities: [Activity] = Activity.mockActivities

    // MARK: - PDF Import state
    var isExtracting: Bool = false
    var isImporting: Bool = false
    var currentPageImporting: Int = 0
    var totalPagesImporting: Int = 0
    var extractedPages: [String] = []
    var importError: String? = nil

    private let extractor: DocumentTextExtracting

    public init(extractor: DocumentTextExtracting = PDFTextExtractor()) {
        self.extractor = extractor
    }

    // MARK: - Manual activity management

    public func addActivity(_ activity: Activity) {
        activities.insert(activity, at: 0)
    }

    public func deleteActivity(at offsets: IndexSet) {
        activities.remove(atOffsets: offsets)
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

    /// Step 2 — send extracted pages to on-device LLM and add results to the activity list.
    func analyzeWithAI(onComplete: @escaping () -> Void) {
        guard !extractedPages.isEmpty else { return }

        isImporting = true
        importError = nil
        currentPageImporting = 0
        totalPagesImporting = extractedPages.count

        Task {
            do {
                let newActivities = try await FoundationModelsService.shared.extractActivities(
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
                        self.activities.insert(activity, at: 0)
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
