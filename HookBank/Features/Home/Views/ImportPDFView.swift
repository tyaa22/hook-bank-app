import SwiftUI
import SwiftData
import UniformTypeIdentifiers

public struct ImportPDFView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: HomeViewModel

    enum ImportState {
        case empty
        case extracting(filename: String)
        case extracted(filename: String)
        case analyzing
        case error(String)
    }

    @State private var state: ImportState = .empty
    @State private var showFilePicker = false
    @State private var selectedURL: URL? = nil

    let grayBackground = Color(white: 0.95)
    let orangeColor = Color(red: 224/255, green: 122/255, blue: 63/255)

    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(grayBackground)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Import PDF")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                // Invisible placeholder to keep the title perfectly centered
                Circle()
                    .frame(width: 32, height: 32)
                    .opacity(0)
            }
            .padding()

            Spacer()

            contentArea

            Spacer()

            bottomButton
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                selectedURL = url
                state = .extracting(filename: url.lastPathComponent)
                viewModel.handleFileSelection(url: url)
            case .failure(let error):
                state = .error(error.localizedDescription)
            }
        }
        // Watch ViewModel state to drive local UI transitions
        .onChange(of: viewModel.isExtracting) { _, extracting in
            if !extracting {
                if let error = viewModel.importError {
                    state = .error(error)
                } else if let url = selectedURL {
                    state = .extracted(filename: url.lastPathComponent)
                }
            }
        }
        .onChange(of: viewModel.importError) { _, error in
            if let error {
                state = .error(error)
            }
        }
        .onAppear {
            if case .empty = state {
                showFilePicker = true
            }
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        switch state {
        case .empty:
            VStack(spacing: 8) {
                Text("No PDF selected")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Text("Choose a PDF to get started.")
                    .font(.body)
                    .foregroundColor(.gray)
            }

        case .extracting(let filename):
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(orangeColor)
                        .font(.title2)
                    Text(filename)
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                }
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(orangeColor)
                    Text("Reading PDF…")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(grayBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)

        case .extracted(let filename):
            HStack(alignment: .center) {
                Image(systemName: "doc.fill")
                    .foregroundColor(orangeColor)
                    .font(.title2)
                    .padding(.trailing, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(filename)
                        .font(.body)
                        .foregroundColor(.black)
                    Text("\(viewModel.extractedPages.count) page\(viewModel.extractedPages.count == 1 ? "" : "s") extracted")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                Button(action: {
                    state = .empty
                    selectedURL = nil
                    viewModel.extractedPages = []
                    viewModel.importError = nil
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }
            .padding()
            .background(grayBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)

        case .analyzing:
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(orangeColor)
                        .font(.title2)
                    Text("Analyzing with AI…")
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 6)
                            Capsule()
                                .fill(orangeColor)
                                .frame(
                                    width: viewModel.totalPagesImporting > 0
                                        ? geometry.size.width * CGFloat(viewModel.currentPageImporting) / CGFloat(viewModel.totalPagesImporting)
                                        : 0,
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                    Text("Page \(viewModel.currentPageImporting) of \(viewModel.totalPagesImporting)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(grayBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)

        case .error(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.largeTitle)
                Text("Something went wrong")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Bottom Button

    @ViewBuilder
    private var bottomButton: some View {
        switch state {
        case .empty:
            Button(action: { showFilePicker = true }) {
                Text("Choose File")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(orangeColor)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

        case .extracting, .analyzing:
            Button(action: {}) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Analyze with AI")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(white: 0.8))
                .cornerRadius(30)
            }
            .disabled(true)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

        case .extracted:
            Button(action: {
                state = .analyzing
                viewModel.analyzeWithAI(context: context) {
                    dismiss()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Analyze with AI")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(orangeColor)
                .cornerRadius(30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

        case .error:
            Button(action: {
                state = .empty
                selectedURL = nil
                viewModel.extractedPages = []
                viewModel.importError = nil
                showFilePicker = true
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(orangeColor)
                    .cornerRadius(30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    ImportPDFView(viewModel: HomeViewModel())
}
