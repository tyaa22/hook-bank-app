import Foundation
import PDFKit

public protocol DocumentTextExtracting: Sendable {
    func extractText(from url: URL) async throws -> [String]
}

public final class PDFTextExtractor: DocumentTextExtracting, @unchecked Sendable {
    public init() {}
    
    public func extractText(from url: URL) async throws -> [String] {
        let gotAccess = url.startAccessingSecurityScopedResource()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                defer {
                    if gotAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                guard let pdf = PDFDocument(url: url) else {
                    continuation.resume(throwing: URLError(.cannotOpenFile))
                    return
                }
                
                var pages: [String] = []
                for i in 0..<pdf.pageCount {
                    if let page = pdf.page(at: i), let text = page.string {
                        pages.append(text)
                    }
                }
                continuation.resume(returning: pages)
            }
        }
    }
}
