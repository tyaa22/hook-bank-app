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
    @State private var selectedActivity: Activity? = nil
    @State private var showImportPDFSheet: Bool = false
    @State private var isSelectionMode: Bool = false
    @State private var selectedIcebreakers: Set<UUID> = []
    @State private var showDeleteConfirm : Bool = false
    
    @State private var isSearchActive: Bool = false
    
    let grayBackground = Color("CardBackgroundColor")
    
    public init() {}
    
    /// Resolved against the live `@Query` result, so deleted Icebreakers drop out on their own.
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
                if activities.isEmpty && drafts.isEmpty {
                    emptyStateView
                }
                else {
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
                                    withAnimation {
                                        isSelectionMode.toggle()
                                        if !isSelectionMode {
                                            selectedIcebreakers.removeAll()
                                        }
                                    }
                                } label: {
                                    Text(isSelectionMode ? "Cancel" : "Select")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.black)
                                        .frame(width: isSelectionMode ? 60 : 44, height: 44)
                                        .padding(.horizontal, isSelectionMode ? 10 : 15)
                                        .clipShape(Capsule())
                                        .glassEffect()
                                }
                                
                                // Filter button                         }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                        
                        List {
                            // MARK: - Draft Icebreaker Section
                                // Only show Draft Icebreaker section if there are actual drafts
                                if !drafts.isEmpty {
                                    if !isSelectionMode && !isSearchActive {
                                        HStack(spacing: 8) {
                                            Text("Draft Icebreaker")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            NavigationLink(destination: DraftsListView(viewModel: viewModel)) {
                                                EmptyView()
                                            }
                                                .opacity(0)
                                        )
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(Color.clear)
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
                                                    .padding(.leading, 4)
                                            }
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 100)
                                                    .fill(grayBackground)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                context.delete(draft)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                selectedDraft = draft
                                                showAddSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.orange)
                                        }
                                        .contextMenu {
                                            Button {
                                                selectedDraft = draft
                                                showAddSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                context.delete(draft)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
//                                    else {
//                                    Text("No saved drafts")
//                                        .font(.subheadline)
//                                        .foregroundColor(.gray)
//                                        .padding(.leading, 4)
//                                        .listRowSeparator(.hidden)
//                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
//                                        .listRowBackground(Color.clear)
//                                }
                            }
                            
                            // MARK: - List Icebreaker Section
                            Text("List Icebreaker")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                            
                            ForEach(filteredActivities) { activity in
                                if isSelectionMode {
                                    Button {
                                        if selectedIcebreakers.contains(activity.id) {
                                            selectedIcebreakers.remove(activity.id)
                                        } else {
                                            selectedIcebreakers.insert(activity.id)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            if selectedIcebreakers.contains(activity.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color("PrimaryAccentColor"))
                                                    .font(.system(size: 24))
                                            } else {
                                                Image(systemName: "circle")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 24))
                                            }
                                            
                                            ActivityCard(activity: activity)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color("PrimaryAccentColor"), lineWidth: selectedIcebreakers.contains(activity.id) ? 2 : 0)
                                                )
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowBackground(Color.clear)
                                } else {
                                    ActivityCard(activity: activity)
                                        .background(
                                            NavigationLink(destination: ActivityDetailView(activity: activity, viewModel: viewModel)) {
                                                EmptyView()
                                            }
                                                .opacity(0)
                                        )
                                        .buttonStyle(PlainButtonStyle())
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5))
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                context.delete(activity)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                selectedActivity = activity
                                                showAddSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            .tint(.orange)
                                        }
                                        .contextMenu {
                                            Button {
                                                selectedActivity = activity
                                                showAddSheet = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            Button(role: .destructive) {
                                                context.delete(activity)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .searchable(text: $searchText, isPresented: $isSearchActive, prompt: "Search")
            .toolbar {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    
                    if isSelectionMode {
                        Button{
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color.red)
                                .clipShape(Capsule())
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                        }
                        .disabled(selectedIcebreakers.isEmpty)
                        .confirmationDialog(
                            selectedIcebreakers.count > 1 ? "Delete \(selectedIcebreakers.count) Icebreakers?" : "Delete Icebreaker?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Keep") {
                                showDeleteConfirm.toggle()
                            }
                            Button("Delete", role: .destructive) {
                                deleteSelectedIcebreakers()
                            }
                        } message: {
                            Text("This action cannot be undone.")
                        }
                    } else {
                        addIcebreakerMenu
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                selectedDraft = nil
                selectedActivity = nil
            }) {
                AddIcebreakerView(viewModel: viewModel, activityToEdit: selectedActivity, draftToEdit: selectedDraft)
            }
            .sheet(isPresented: $showImportPDFSheet) {
                ImportPDFView(viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .toolbarBackground(.clear, for: .bottomBar)
        }
        
    }
    
    private var addIcebreakerMenu: some View {
        Menu {
            Button {
                showAddSheet = true
            } label: {
                Label("Add Manually", systemImage: "pencil")
            }
            
            Button {
                showImportPDFSheet = true
            } label: {
                Label("Import PDF", systemImage: "doc.fill")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 35, height: 35)
//                .background(Color("PrimaryAccentColor"), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    private func deleteSelectedIcebreakers() {
        for activity in activities where selectedIcebreakers.contains(activity.id) {
            context.delete(activity)
        }
        selectedIcebreakers.removeAll()
        isSelectionMode = false
    }
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image("home_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .padding(.bottom, 8)
            
            Text("No Entries")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Text("To add an entry, tap the plus button")
                .font(.subheadline)
                .foregroundColor(Color("DescriptionColor"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .frame(maxWidth: .infinity)
                .padding(.top, 120)

        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Activity.self, DraftActivity.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for activity in Activity.mockActivities {
        container.mainContext.insert(activity)
    }
    container.mainContext.insert(DraftActivity(name: "Untitled Draft"))

    return HomeView()
        .modelContainer(container)
}
