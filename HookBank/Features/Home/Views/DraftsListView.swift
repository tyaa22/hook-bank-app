import SwiftUI
import SwiftData
import Core

public struct DraftsListView: View {
    @Query(sort: \DraftActivity.lastUpdated, order: .reverse) private var drafts: [DraftActivity]
    @State private var showAddSheet: Bool = false
    @State private var selectedDraft: DraftActivity? = nil
    
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
                ScrollView {
                    LazyVStack(spacing: 16) {
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
                            .accessibilityLabel(Text("\(draft.name), draft"))
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar) // Ensures native back button is visible
        .sheet(isPresented: $showAddSheet, onDismiss: {
            selectedDraft = nil
        }) {
            AddHookView(viewModel: viewModel, draftToEdit: selectedDraft)
        }
    }
}
