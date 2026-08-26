import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct PDFExtractionView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PDFExtractionViewModel()
    @State private var isImporterPresented = false
    @State private var copiedAll = false
    @State private var copiedPageIndex: Int? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Content Area ──────────────────────────────────────────
                Group {
                    if viewModel.isExtracting {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("Extracting text from PDF…")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if viewModel.extractedPages.isEmpty {
                        emptyStateView

                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("PDF Preview (\(viewModel.extractedPages.count) Page\(viewModel.extractedPages.count == 1 ? "" : "s") Extracted)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    UIPasteboard.general.string = viewModel.extractedPages.joined(separator: "\n\n")
                                    withAnimation {
                                        copiedAll = true
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                                        withAnimation {
                                            copiedAll = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: copiedAll ? "checkmark.circle.fill" : "doc.on.doc")
                                        Text(copiedAll ? "Copied" : "Copy All")
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(copiedAll ? .green : .indigo)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    ForEach(0..<viewModel.extractedPages.count, id: \.self) { index in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text("Page \(index + 1)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.indigo)
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    UIPasteboard.general.string = viewModel.extractedPages[index]
                                                    withAnimation {
                                                        copiedPageIndex = index
                                                    }
                                                    Task {
                                                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                                                        withAnimation {
                                                            if copiedPageIndex == index {
                                                                copiedPageIndex = nil
                                                            }
                                                        }
                                                    }
                                                }) {
                                                    Image(systemName: copiedPageIndex == index ? "checkmark.circle.fill" : "doc.on.doc")
                                                        .font(.caption)
                                                        .foregroundColor(copiedPageIndex == index ? .green : .secondary)
                                                }
                                            }
                                            
                                            Text(viewModel.extractedPages[index])
                                                .font(.system(.caption2, design: .monospaced))
                                                .padding(8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(UIColor.tertiarySystemBackground))
                                                .cornerRadius(6)
                                        }
                                        .padding(.bottom, 4)
                                    }
                                }
                                .padding()
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Import Result Banner ──────────────────────────────────
                if let result = viewModel.importResult {
                    resultBanner(result)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // ── Action Buttons ────────────────────────────────────────
                VStack(spacing: 12) {
                    if !viewModel.extractedPages.isEmpty && !viewModel.isExtracting {
                        Button(action: { viewModel.importWithAI(modelContext: modelContext) }) {
                            HStack(spacing: 8) {
                                if viewModel.isImporting {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(viewModel.isImporting
                                     ? "Extracting Page \(viewModel.currentPageImporting) of \(viewModel.totalPagesImporting)…"
                                     : "Import Activities with AI")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isImporting)
                    }

                    Button(action: { isImporterPresented = true }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Select PDF")
                                .fontWeight(.semibold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isExtracting || viewModel.isImporting)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
            }
            .navigationTitle("PDF Importer")
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileSelection(result: result)
            }
        }
    }

    // MARK: - Sub-Views

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("No PDF Selected")
                    .font(.title3.weight(.semibold))
                Text("Select a PDF and use AI to extract\nall activities page by page.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func resultBanner(_ outcome: PDFExtractionViewModel.ImportOutcome) -> some View {
        switch outcome {
        case .success(let count):
            Label(
                "\(count) activit\(count == 1 ? "y" : "ies") imported and saved.",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundColor(.green)
            .font(.subheadline.weight(.medium))
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.12))
            .cornerRadius(10)

        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.subheadline.weight(.medium))
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.12))
                .cornerRadius(10)
        }
    }
}

#Preview {
    PDFExtractionView()
        .modelContainer(for: Activity.self, inMemory: true)
}
