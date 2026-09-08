import SwiftUI
import SwiftData
import Core

public struct AddIcebreakerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var viewModel: HomeViewModel
    var activityToEdit: Activity? = nil
    @State private var draftToEdit: DraftActivity? = nil
    @State private var showDismissDialog: Bool = false
    
    @State private var title: String = ""
    @State private var selectedCategories: Set<String> = []
    @State private var idealParticipants: Int? = nil
    @State private var durationMin: Int = 10
    @State private var durationMax: Int = 20
    @State private var goal: String = ""
    
    // Materials
    
    @State private var materials: [String] = []
    @State private var newMaterial: String = ""
    @FocusState private var isMaterialFieldFocused: Bool
    @State private var materialDebounceTask: Task<Void, Never>? = nil
    
    // Instructions
    @State private var howToPlay: String = ""
    
    let grayBackground = Color("CardBackgroundColor")
    private var isEditMode: Bool { activityToEdit != nil }
    private var headerTitle: String { isEditMode ? "Edit Icebreaker" : "Add Icebreaker" }
    
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
                    categorySection
                    participantSection
                    durationSection
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
            .background(InteractiveDismissTracker {
                handleCancelTapped()
            })
            .confirmationDialog("What would you like to do with this draft?", isPresented: $showDismissDialog, titleVisibility: .visible) {
                Button("Delete Draft", role: .destructive) {
                    deleteDraftAndDismiss()
                }
                Button("Save Draft") {
                    saveDraftAndDismiss()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
        .interactiveDismissDisabled(true)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onAppear { prefillIfEditing() }
        .onChange(of: title) { _, _ in autoSaveDraft() }
        .onChange(of: selectedCategories) { _, _ in autoSaveDraft() }
        .onChange(of: idealParticipants) { _, _ in autoSaveDraft() }
        .onChange(of: durationMin) { _, _ in autoSaveDraft() }
        .onChange(of: durationMax) { _, _ in autoSaveDraft() }
        .onChange(of: goal) { _, _ in autoSaveDraft() }
        .onChange(of: materials) { _, _ in autoSaveDraft() }
        .onChange(of: howToPlay) { _, _ in autoSaveDraft() }
    }
    
    // MARK: - Helpers

    /// Whether the form has anything a user would lose by dismissing — every field counts, not
    /// just the text ones, so picking categories or typing a participant count without touching
    /// Title/Goal/Instructions still triggers the discard confirmation (and still gets autosaved,
    /// since `autoSaveDraft()` shares this same check).
    private var hasUnsavedContent: Bool {
        !title.isEmpty
            || !goal.isEmpty
            || !howToPlay.isEmpty
            || !materials.isEmpty
            || !selectedCategories.isEmpty
            || idealParticipants != nil
            || durationMin != 10
            || durationMax != 20
    }

    private func handleCancelTapped() {
        if hasUnsavedContent {
            showDismissDialog = true
        } else {
            dismiss()
        }
    }

    private func prefillIfEditing() {
        if let activity = activityToEdit {
            title = activity.name
            goal = activity.goal
            howToPlay = activity.howToPlay
            materials = activity.possibleProperties.filter { $0 != "-" }
            idealParticipants = activity.participants
            selectedCategories = Set(activity.categories)
            (durationMin, durationMax) = Self.parseDuration(activity.duration)
        } else if let draft = draftToEdit {
            title = draft.name
            idealParticipants = draft.participants
            selectedCategories = Set(draft.categories)
            (durationMin, durationMax) = Self.parseDuration(draft.duration)
            goal = draft.goal
            howToPlay = draft.howToPlay
            materials = draft.possibleProperties
        }
    }

    /// Recovers the minute range this view's Minimum/Maximum fields need from a stored duration
    /// string like "10-20 minutes" or "15 minutes"; falls back to a sensible default when the
    /// string carries no numbers (e.g. the "-" placeholder).
    private static func parseDuration(_ duration: String) -> (min: Int, max: Int) {
        let numbers = duration
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        guard let first = numbers.first else { return (10, 20) }
        let last = numbers.last ?? first
        return (min(first, last), max(first, last))
    }

    private func composedDuration() -> String {
        durationMin == durationMax ? "\(durationMin) minutes" : "\(durationMin)-\(durationMax) minutes"
    }

    private func autoSaveDraft() {
        // Only auto-save if we are not editing an existing icebreaker
        guard !isEditMode else { return }
        // Do not auto-save if all fields are empty
        guard hasUnsavedContent else { return }

        let finalParticipants = idealParticipants ?? 10
        if let draft = draftToEdit {
            draft.name = title
            draft.participants = finalParticipants
            draft.duration = composedDuration()
            draft.categories = Array(selectedCategories)
            draft.goal = goal
            draft.howToPlay = howToPlay
            draft.possibleProperties = materials
            draft.lastUpdated = Date()
        } else {
            let newDraft = DraftActivity(
                name: title,
                participants: finalParticipants,
                duration: composedDuration(),
                categories: Array(selectedCategories),
                goal: goal,
                howToPlay: howToPlay,
                possibleProperties: materials
            )
            context.insert(newDraft)
            draftToEdit = newDraft // So subsequent edits update the same draft
        }
    }

    private func saveIcebreaker() {
        let finalParticipants = idealParticipants ?? 10
        let categories = Array(selectedCategories)
        if isEditMode, let original = activityToEdit {
            original.name = title
            original.participants = finalParticipants
            original.duration = composedDuration()
            original.categories = categories
            original.goal = goal
            original.howToPlay = howToPlay
            original.possibleProperties = materials
        } else {
            let newIcebreaker = Activity(
                name: title,
                participants: finalParticipants,
                duration: composedDuration(),
                categories: categories,
                goal: goal,
                howToPlay: howToPlay,
                possibleProperties: materials
            )
            context.insert(newIcebreaker)

            // Clean up the draft if it was saved
            if let draft = draftToEdit {
                context.delete(draft)
            }
        }
        dismiss()
    }
    
    private func deleteDraftAndDismiss() {
        if let draft = draftToEdit, !isEditMode {
            context.delete(draft)
        }
        dismiss()
    }
    
    private func saveDraftAndDismiss() {
        // Already auto-saved by onChange
        dismiss()
    }
    
    // MARK: - Subviews
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title")
                .font(.subheadline)
                .fontWeight(.bold)

            TextField("Give your activity a title", text: $title)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.subheadline)
                .fontWeight(.bold)

            CategoryChipEditor(selectedCategories: $selectedCategories)
        }
    }

    private var participantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ideal Number of Participant")
                .font(.subheadline)
                .fontWeight(.bold)

            TextField("e.g. 50", value: $idealParticipants, format: .number)
                .keyboardType(.numberPad)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Duration Activity")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("(minutes)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("Minimum")
                        .foregroundColor(Color(white: 0.7))
                    Spacer()
                    TextField("", value: $durationMin, format: .number)
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
                    TextField("", value: $durationMax, format: .number)
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
            .onChange(of: durationMin) { _, newValue in
                if newValue > 500 { durationMin = 500 }
                else if newValue < 1 { durationMin = 1 }

                if durationMax < durationMin {
                    durationMax = durationMin
                }
            }
            .onChange(of: durationMax) { _, newValue in
                if newValue > 500 { durationMax = 500 }
                else if newValue < durationMin { durationMax = durationMin }
            }
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal")
                .font(.subheadline)
                .fontWeight(.bold)

            TextField("What should participants achieve?", text: $goal, axis: .vertical)
                .lineLimit(4...8)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Material")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("(optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

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
                    TextField("e.g. Stickers, paper, etc.", text: $newMaterial)
                        .focused($isMaterialFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !materials.contains(trimmed) {
                                materials.append(trimmed)
                                newMaterial = ""
                                isMaterialFieldFocused = true
                            }
                        }
                        .onChange(of: newMaterial) { _, newValue in
                            materialDebounceTask?.cancel()
                            
                            guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            
                            materialDebounceTask = Task {
                                try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s delay
                                guard !Task.isCancelled else { return }
                                
                                await MainActor.run {
                                    let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && !materials.contains(trimmed) {
                                        materials.append(trimmed)
                                        newMaterial = ""
                                    }
                                }
                            }
                        }

//                    if isMaterialFieldFocused {
//                        Button(action: {
//                            let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
//                            if !trimmed.isEmpty && !materials.contains(trimmed) {
//                                materials.append(trimmed)
//                                newMaterial = ""
//                            }
//                        }) {
//                            Image(systemName: "plus.circle.fill")
//                                .font(.system(size: 24))
//                                .foregroundColor(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color("PrimaryAccentColor"))
//                        }
//                        .disabled(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//                    }
                }
            }
            .padding()
            .background(grayBackground)
            .cornerRadius(20)
        }
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.subheadline)
                .fontWeight(.bold)

            TextField("Describe how to run this activity", text: $howToPlay, axis: .vertical)
                .lineLimit(6...12)
                .padding()
                .background(grayBackground)
                .cornerRadius(20)
        }
    }
    
    @ToolbarContentBuilder
    private var toolBarSection: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                handleCancelTapped()
            } label: {
                Image(systemName: "xmark")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button(action: saveIcebreaker) {
                Image(systemName: "checkmark")
            }
            .disabled(title.isEmpty || goal.isEmpty || howToPlay.isEmpty)
        }
    }
}

#Preview("Add Mode") {
    AddIcebreakerView(viewModel: HomeViewModel())
}

#Preview("Edit Mode") {
    AddIcebreakerView(viewModel: HomeViewModel(), activityToEdit: Activity.mockActivities[0])
}

struct InteractiveDismissTracker: UIViewControllerRepresentable {
    var onAttemptToDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            // Find the presentation controller and hijack its delegate
            vc.parent?.presentationController?.delegate = context.coordinator
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onAttemptToDismiss: onAttemptToDismiss)
    }
    
    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var onAttemptToDismiss: () -> Void
        
        init(onAttemptToDismiss: @escaping () -> Void) {
            self.onAttemptToDismiss = onAttemptToDismiss
        }
        
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttemptToDismiss()
        }
        
        // This ensures the sheet doesn't dismiss on its own when the delegate is set
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            return false
        }
    }
}
