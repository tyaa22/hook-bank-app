import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ActivitySearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            PDFExtractionView()
                .tabItem {
                    Label("PDF Tool", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    ContentView()
}
