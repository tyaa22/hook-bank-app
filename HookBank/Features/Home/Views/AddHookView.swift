import SwiftUI
import SwiftData
import Core

public struct AddHookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var viewModel: HomeViewModel
    var activityToEdit: Activity? = nil
    @State private var draftToEdit: DraftActivity? = nil
    
    @State private var title: String = ""
    @State private var minParticipants: Int = 1
    @State private var maxParticipants: Int = 10
    @State private var goal: String = ""
    
    // Materials
    
    @State private var materials: [String] = []
    @State private var newMaterial: String = ""
    @FocusState private var isMaterialFieldFocused: Bool
    
    // Instructions
    @State private var howToPlay: String = ""
    
    let grayBackground = Color("CardBackgroundColor")
    private var isEditMode: Bool { activityToEdit != nil }
    private var headerTitle: String { isEditMode ? "Edit Hook" : "Add Hook" }
    
    public init(viewModel: HomeViewModel, activityToEdit: Activity? = nil, draftToEdit: DraftActivity? = nil) {
        self.viewModel = viewModel
        self.activityToEdit = activityToEdit
        self._draftToEdit = State(initialValue: draftToEdit)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    participantSection
                    goalSection
                    materialSection
                    instructionsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolBarSection
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear { prefillIfEditing() }
        .onChange(of: title) { _, _ in autoSaveDraft() }
        .onChange(of: minParticipants) { _, _ in autoSaveDraft() }
        .onChange(of: maxParticipants) { _, _ in autoSaveDraft() }
        .onChange(of: goal) { _, _ in autoSaveDraft() }
        .onChange(of: materials) { _, _ in autoSaveDraft() }
        .onChange(of: howToPlay) { _, _ in autoSaveDraft() }
    }
    
    // MARK: - Helpers
    
    private func prefillIfEditing() {
        if let activity = activityToEdit {
            title = activity.name
            goal = activity.goal
            howToPlay = activity.howToPlay
            materials = activity.possibleProperties.filter { $0 != "-" }
            
            let parts = activity.participants.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 {
                minParticipants = parts[0]
                maxParticipants = parts[1]
            } else if let single = parts.first {
                minParticipants = single
                maxParticipants = single
            }
        } else if let draft = draftToEdit {
            title = draft.name
            minParticipants = draft.minParticipants
            maxParticipants = draft.maxParticipants
            goal = draft.goal
            howToPlay = draft.howToPlay
            materials = draft.possibleProperties
        }
    }
    
    private func autoSaveDraft() {
        // Only auto-save if we are not editing an existing hook
        guard !isEditMode else { return }
        // Do not auto-save if all fields are empty
        guard !title.isEmpty || !goal.isEmpty || !howToPlay.isEmpty || !materials.isEmpty else { return }
        
        if let draft = draftToEdit {
            draft.name = title
            draft.minParticipants = minParticipants
            draft.maxParticipants = maxParticipants
            draft.goal = goal
            draft.howToPlay = howToPlay
            draft.possibleProperties = materials
            draft.lastUpdated = Date()
        } else {
            let newDraft = DraftActivity(
                name: title,
                minParticipants: minParticipants,
                maxParticipants: maxParticipants,
                goal: goal,
                howToPlay: howToPlay,
                possibleProperties: materials
            )
            context.insert(newDraft)
            draftToEdit = newDraft // So subsequent edits update the same draft
        }
    }
    
    private func saveHook() {
        let participantString = minParticipants == maxParticipants ? "\(minParticipants)" : "\(minParticipants)-\(maxParticipants)"
        if isEditMode, let original = activityToEdit {
            original.name = title
            original.participants = participantString
            original.goal = goal
            original.howToPlay = howToPlay
            original.possibleProperties = materials
        } else {
            let newHook = Activity(
                name: title,
                participants: participantString,
                goal: goal,
                howToPlay: howToPlay,
                possibleProperties: materials
            )
            context.insert(newHook)
            
            // Clean up the draft if it was saved
            if let draft = draftToEdit {
                context.delete(draft)
            }
        }
        dismiss()
    }
    
    // MARK: - Subviews
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.subheadline)
                .fontWeight(.bold)
            
            TextField("Required", text: $title)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }
    
    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Participant")
                .font(.subheadline)
                .fontWeight(.bold)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Minimum")
                        .foregroundColor(Color(white: 0.7))
                    Spacer()
                    TextField("", value: $minParticipants, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .cornerRadius(8)
                }
                .padding()
                
                Divider().padding(.horizontal)
                
                HStack {
                    Text("Maximum")
                        .foregroundColor(Color(white: 0.7))
                    Spacer()
                    TextField("", value: $maxParticipants, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .cornerRadius(8)
                }
                .padding()
            }
            .background(grayBackground)
            .cornerRadius(20)
            .onChange(of: minParticipants) { _, newValue in
                if newValue > 100 { minParticipants = 100 }
                else if newValue < 1 { minParticipants = 1 }
                
                if maxParticipants < minParticipants {
                    maxParticipants = minParticipants
                }
            }
            .onChange(of: maxParticipants) { _, newValue in
                if newValue > 100 { maxParticipants = 100 }
                else if newValue < minParticipants { maxParticipants = minParticipants }
            }
        }
    }
    
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal")
                .font(.subheadline)
                .fontWeight(.bold)
            
            TextField("Required", text: $goal, axis: .vertical)
                .lineLimit(4...8)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }
    
    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Material")
                .font(.subheadline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 12) {
                if !materials.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(materials, id: \.self) { material in
                            HStack {
                                Text("• \(material)")
                                Spacer()
                                Button(action: {
                                    materials.removeAll { $0 == material }
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                HStack {
                    TextField("Optional", text: $newMaterial)
                        .focused($isMaterialFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !materials.contains(trimmed) {
                                materials.append(trimmed)
                                newMaterial = ""
                                // Keep the field focused to allow adding multiple materials quickly
                                isMaterialFieldFocused = true
                            }
                        }
                    
                    if isMaterialFieldFocused {
                        Button(action: {
                            let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !materials.contains(trimmed) {
                                materials.append(trimmed)
                                newMaterial = ""
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color("PrimaryAccentColor"))
                        }
                        .disabled(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding()
            .background(grayBackground)
            .cornerRadius(20)
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to Play")
                .font(.subheadline)
                .fontWeight(.bold)
            
            TextField("Required", text: $howToPlay, axis: .vertical)
                .lineLimit(6...12)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }
    
    @ToolbarContentBuilder
    private var toolBarSection: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.black)
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 30, height: 30)
            .tint(Color.gray.opacity(0.3))
            .buttonBorderShape(.circle)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            Button(action: saveHook) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .regular))
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 30, height: 30)
            .tint(Color("PrimaryAccentColor"))
            .buttonBorderShape(.circle)
            .disabled(title.isEmpty || goal.isEmpty || howToPlay.isEmpty)
        }
    }
}

#Preview("Add Mode") {
    AddHookView(viewModel: HomeViewModel())
}

#Preview("Edit Mode") {
    AddHookView(viewModel: HomeViewModel(), activityToEdit: Activity.mockActivities[0])
}
