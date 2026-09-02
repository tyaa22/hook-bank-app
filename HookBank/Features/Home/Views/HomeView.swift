import SwiftUI
import SwiftData
import Core

public struct HomeView: View {
    @Query(sort: \Activity.name) private var activities: [Activity]
    @Query(sort: \DraftActivity.lastUpdated, order: .reverse) private var drafts: [DraftActivity]
    
    @Environment(\.modelContext) private var context
    @State private var viewModel = HomeViewModel()
    @State private var searchText: String = ""
    @State private var showAddSheet: Bool = false
    @State private var selectedDraft: DraftActivity? = nil
    @State private var showImportPDFSheet: Bool = false
    let grayBackground = Color("CardBackgroundColor")
    
    public init() {}
    
    var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return activities
        } else {
            return NLSearchService.shared.search(query: searchText, activities: activities)
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background color matching standard iOS grouped background
                Color(Color("BackgroundColor"))
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                VStack(spacing: 0) {
                    // Custom Toolbar
                    HStack {
                        Text("Sparkleash")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button {
                                // Action for first button
                            } label: {
                                Text("Select")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .padding(.horizontal, 15)
                                    .clipShape(Circle())
                                    .glassEffect()
                            }
                            
                            Button {
                                // Action for second button
                            } label: {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(.black)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .glassEffect()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                //                            Text("Newly Added")
                                //                                .font(.title2)
                                //                                .fontWeight(.bold)
                                //                                .foregroundColor(.black)
                                //                                .padding(.top, 8)
                                //
                                //                            if let firstActivity = filteredActivities.first {
                                //                                NavigationLink(destination: ActivityDetailView(activity: firstActivity, viewModel: viewModel)) {
                                //                                    ActivityCard(activity: firstActivity)
                                //                                }
                                //                                .buttonStyle(PlainButtonStyle())
                                //                            }
                                
                                // MARK: - Draft Hook Section
                                VStack(alignment: .leading, spacing: 12) {
                                    NavigationLink(destination: DraftsListView(viewModel: viewModel)) {
                                        HStack(spacing: 8) {
                                            Text("Draft Hook")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.top, 8)
                                    
                                    // Only show Draft Hook section if there are actual drafts
                                    if !drafts.isEmpty {
                                        // To change the maximum number of drafts shown on this screen,
                                        // change the number inside `prefix(...)` (e.g., `.prefix(2)`)
                                        ForEach(drafts.prefix(3)) { draft in
                                            Button {
                                                selectedDraft = draft
                                                showAddSheet = true
                                            } label: {
                                                HStack {
                                                    Text(draft.name.isEmpty ? "Untitled" : draft.name)
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.black)
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(.gray)
                                                }
                                                .padding()
                                                .background(
                                                    RoundedRectangle(cornerRadius: 100)
                                                        .fill(grayBackground)
                                                )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    } else {
                                        // Placeholder so the user can still access the Add Hook sheet easily if they want to
                                        // Or you can completely hide the Drafts section if there are none. For now we will hide the cards.
                                        Text("No saved drafts")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.leading, 4)
                                    }
                                }
                                
                                // MARK: - List Hook Section
                                Text("List Hook")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.black)
                                    .padding(.top, 16)
                                
                                ForEach(filteredActivities) { activity in
                                    NavigationLink(destination: ActivityDetailView(activity: activity, viewModel: viewModel)) {
                                        ActivityCard(activity: activity)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                
                ToolbarSpacer(.fixed, placement: .bottomBar)
                
                ToolbarItem(placement: .bottomBar) {
                    Menu {
                        Button {
                            showAddSheet = true
                        }label: {
                            Label("Add Manually", systemImage: "pencil")
                        }
                        
                        Button {
                            showImportPDFSheet = true
                        }label: {
                            Label("Import PDF", systemImage: "doc.fill")
                        }
                        
                    } label: {
                        Label("Add Hook", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                selectedDraft = nil
            }) {
                AddHookView(viewModel: viewModel, draftToEdit: selectedDraft)
            }
            .sheet(isPresented: $showImportPDFSheet) {
                ImportPDFView(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    HomeView()
}
