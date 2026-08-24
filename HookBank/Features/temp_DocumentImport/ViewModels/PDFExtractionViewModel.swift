import SwiftUI
import Combine
import SwiftData

@MainActor
class PDFExtractionViewModel: ObservableObject {
    @Published var isExtracting = false
    @Published var isImporting = false
    @Published var currentPageImporting = 0
    @Published var totalPagesImporting = 0
    @Published var extractedPages: [String] = []
    @Published var importResult: ImportOutcome? = nil
    
    enum ImportOutcome {
        case success(Int)
        case failure(String)
    }
    
    private let importService: ActivityImportService
    private let extractor: DocumentTextExtracting
    
    init(importService: ActivityImportService = .shared, extractor: DocumentTextExtracting = PDFTextExtractor()) {
        self.importService = importService
        self.extractor = extractor
    }
    
    func handleFileSelection(result: Result<[URL], Error>) {
        importResult = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            extractText(from: url)
        case .failure(let error):
            importResult = .failure("Error selecting file: \(error.localizedDescription)")
        }
    }
    
    private func extractText(from url: URL) {
        isExtracting = true
        extractedPages = []
        
        Task {
            do {
                self.extractedPages = try await extractor.extractText(from: url)
            } catch {
                self.importResult = .failure("Error reading PDF: \(error.localizedDescription)")
            }
            self.isExtracting = false
        }
    }
    
    func importWithAI(modelContext: ModelContext) {
        guard !extractedPages.isEmpty else { return }
        
        isImporting = true
        importResult = nil
        currentPageImporting = 0
        totalPagesImporting = extractedPages.count
        
        Task {
            do {
                let count = try await importService.importActivities(from: extractedPages, modelContext: modelContext) { [weak self] current, total in
                    guard let self = self else { return }
                    self.currentPageImporting = current
                    self.totalPagesImporting = total
                }
                self.importResult = .success(count)
            } catch {
                self.importResult = .failure(error.localizedDescription)
            }
            self.isImporting = false
        }
    }
}
