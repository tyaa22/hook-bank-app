import SwiftUI
import UniformTypeIdentifiers

public struct ImportPDFView: View {
    @Environment(\.dismiss) private var dismiss
    
    enum ImportState {
        case empty
        case uploading(filename: String, progress: Double)
        case uploaded(filename: String, size: String)
    }
    
    @State private var state: ImportState = .empty
    @State private var showFilePicker = false
    
    let grayBackground = Color(white: 0.95)
    let orangeColor = Color(red: 224/255, green: 122/255, blue: 63/255)
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
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
            
            // Dynamic Content Area
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
            
            case .uploading(let filename, let progress):
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
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 6)
                            Capsule()
                                .fill(orangeColor)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding()
                .background(grayBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
            case .uploaded(let filename, let size):
                HStack(alignment: .center) {
                    Image(systemName: "doc.fill")
                        .foregroundColor(orangeColor)
                        .font(.title2)
                        .padding(.trailing, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filename)
                            .font(.body)
                            .foregroundColor(.black)
                        Text(size)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { state = .empty }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                }
                .padding()
                .background(grayBackground)
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Dynamic Bottom Button Area
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
                
            case .uploading:
                Button(action: {}) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Analyze with AI")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(white: 0.8)) // Disabled state color
                    .cornerRadius(30)
                }
                .disabled(true)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
            case .uploaded:
                Button(action: {
                    // For now, just dismiss the sheet as requested
                    dismiss()
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
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                handleFileSelection(url: url)
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
        .onAppear {
            if case .empty = state {
                // Immediately show file picker on initial load
                showFilePicker = true
            }
        }
    }
    
    private func handleFileSelection(url: URL) {
        let filename = url.lastPathComponent
        
        // Mock a 20 MB size since we don't have real file size calculation yet
        let sizeString = "20 MB" 
        
        state = .uploading(filename: filename, progress: 0.0)
        
        Task {
            // Simulated upload process
            for i in 1...100 {
                // Simulate network delay
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms per tick = 2 seconds total
                await MainActor.run {
                    if case .uploading(let currentFilename, _) = state {
                        state = .uploading(filename: currentFilename, progress: Double(i) / 100.0)
                    }
                }
            }
            
            // Complete state
            await MainActor.run {
                state = .uploaded(filename: filename, size: sizeString)
            }
        }
    }
}

#Preview {
    ImportPDFView()
}
