import SwiftUI

struct FloatingSearchBar: View {
    @Binding var searchText: String
    var onAddManually: () -> Void
    var onImportPDF: () -> Void

    // Tweak this number to change the transparency!
    // 1.0 is full frosted glass. Lower values make it more transparent.
    let glassOpacity: Double = 0.80
    
    var body: some View {
        HStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                    
                    TextField("Search", text: $searchText)
                        .font(.system(size: 16))
                    
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                // Native SwiftUI Liquid Glass implementation:
                .glassEffect()
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Circular Plus Button with Menu
                Menu {
                    Button {
                        onAddManually()
                    } label: {
                        Label("Add Manually", systemImage: "pencil")
                    }
                    Button {
                        onImportPDF()
                    } label: {
                        Label("Import PDF", systemImage: "doc.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .glassEffect(in: Circle())
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }

            }
            else {
                // Search Input Container
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                    
                    TextField("Search", text: $searchText)
                        .font(.system(size: 16))
                    
                    Image(systemName: "mic")
                        .foregroundColor(.gray)
                        .font(.system(size: 18))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                // Native SwiftUI Liquid Glass implementation:
                .background(
                    .ultraThinMaterial.opacity(glassOpacity),
                    in: Capsule() // Using 'in: Capsule()' automatically clips the blur perfectly
                )
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                
                // Circular Plus Button with Menu
                Menu {
                    Button {
                        onAddManually()
                    } label: {
                        Label("Add Manually", systemImage: "pencil")
                    }
                    Button {
                        onImportPDF()
                    } label: {
                        Label("Import PDF", systemImage: "doc.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(
                            .ultraThinMaterial.opacity(glassOpacity),
                            in: Circle()
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    ZStack {
        // I added a busy background to the preview so you can actually see the liquid glass working!
        Color(white: 0.95).ignoresSafeArea()
        Circle()
            .fill(Color.orange.opacity(0.5))
            .frame(width: 200, height: 200)
            .offset(x: -80, y: 350)
            
        VStack {
            Spacer()
            FloatingSearchBar(searchText: .constant(""), onAddManually: {}, onImportPDF: {})
        }
    }
}
