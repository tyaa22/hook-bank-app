import SwiftUI
import SwiftData
import Core

public struct DraftsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DraftActivity.lastUpdated, order: .reverse) private var drafts: [DraftActivity]
    @State private var showAddSheet: Bool = false
    @State private var selectedDraft: DraftActivity? = nil
    @State private var draftToDelete: DraftActivity? = nil
    
    var viewModel: HomeViewModel
    let grayBackground = Color("CardBackgroundColor")
    
    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            Color(Color("BackgroundColor"))
                .ignoresSafeArea()
            
            if drafts.isEmpty {
                VStack {
                    Spacer()
                    Text("No saved drafts")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(drafts) { draft in
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
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                draftToDelete = draft
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
                                draftToDelete = draft
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .confirmationDialog(
                    "Delete Draft Icebreaker",
                    isPresented: Binding(
                        get: { draftToDelete != nil },
                        set: { if !$0 { draftToDelete = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        if let draft = draftToDelete {
                            context.delete(draft)
                        }
                        draftToDelete = nil
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Are you sure you want to delete this draft icebreaker? \nThis action cannot be undone.")
                }
            }
        }
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar) // Ensures native back button is visible
        .sheet(isPresented: $showAddSheet, onDismiss: {
            selectedDraft = nil
        }) {
            AddIcebreakerView(viewModel: viewModel, draftToEdit: selectedDraft)
        }
    }
}

//#Preview {
//    DraftsListView(viewModel: <#T##HomeViewModel#>)
//}
