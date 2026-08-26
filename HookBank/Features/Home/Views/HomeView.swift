import SwiftUI
import Core

public struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var searchText: String = ""
    @State private var showAddSheet: Bool = false
    @State private var showImportPDFSheet: Bool = false
    
    public init() {}
    
    var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return viewModel.activities
        } else {
            return viewModel.activities.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.goal.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background color matching standard iOS grouped background
                Color(Color("BackgroundColor"))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Hook Bank")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        LazyVStack(alignment: .leading, spacing: 16) {
                            Text("Newly Added")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.top, 8)
                            
                            if let firstActivity = filteredActivities.first {
                                ActivityCard(activity: firstActivity)
                            }
                        
                            Text("List Hook")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.top, 16)
                            
                            ForEach(filteredActivities.dropFirst()) { activity in
                                ActivityCard(activity: activity)
                                    
                            }
                            .onDelete(perform: viewModel.deleteActivity)
                        }
                        .padding(.horizontal, 16)
                        
                        // Extra space at bottom so last card isn't hidden by the floating bar
                        Spacer()
                            .frame(height: 80)
                    }
                }
                
                // Floating Search Bar overlay
                FloatingSearchBar(
                    searchText: $searchText,
                    onAddManually: { showAddSheet = true },
                    onImportPDF: { showImportPDFSheet = true }
                )
                .padding(20)
            }
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .sheet(isPresented: $showAddSheet) {
                AddHookView(viewModel: viewModel)
            }
            .sheet(isPresented: $showImportPDFSheet) {
                ImportPDFView(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
        }
    }
}

#Preview {
    HomeView()
}
