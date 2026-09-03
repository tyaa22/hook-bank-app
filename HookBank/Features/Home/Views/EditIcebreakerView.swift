import SwiftUI
import Core

/// Dedicated edit screen for an existing `Activity`, pushed onto the enclosing `NavigationStack`
/// from `ActivityDetailView`'s pencil button — unlike `AddIcebreakerView` (used for creating new
/// Icebreakers, or editing via a sheet elsewhere), this one is a full page with a native back
/// button that confirms before discarding unsaved edits, and a floating Save button.
struct EditIcebreakerView: View {
    let activity: Activity

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var selectedCategories: Set<String>
    @State private var idealParticipants: Int?
    @State private var durationMin: Int
    @State private var durationMax: Int
    @State private var goal: String
    @State private var materials: [String]
    @State private var newMaterial: String = ""
    @FocusState private var isMaterialFieldFocused: Bool
    @State private var howToPlay: String

    @State private var showDiscardDialog = false

    private let originalTitle: String
    private let originalGoal: String
    private let originalHowToPlay: String
    private let originalMaterials: [String]
    private let originalParticipants: Int
    private let originalDuration: String
    private let originalCategories: Set<String>

    private let grayBackground = Color("CardBackgroundColor")
    private let accent = Color("PrimaryAccentColor")

    init(activity: Activity) {
        self.activity = activity

        let materials = activity.possibleProperties.filter { $0 != "-" }
        let categories = Set(activity.categories)
        let (minutes, maxMinutes) = Self.parseDuration(activity.duration)

        _title = State(initialValue: activity.name)
        _selectedCategories = State(initialValue: categories)
        _idealParticipants = State(initialValue: activity.participants)
        _durationMin = State(initialValue: minutes)
        _durationMax = State(initialValue: maxMinutes)
        _goal = State(initialValue: activity.goal)
        _materials = State(initialValue: materials)
        _howToPlay = State(initialValue: activity.howToPlay)

        originalTitle = activity.name
        originalGoal = activity.goal
        originalHowToPlay = activity.howToPlay
        originalMaterials = materials
        originalParticipants = activity.participants
        originalDuration = activity.duration
        originalCategories = categories
    }

    private var isDirty: Bool {
        title != originalTitle
            || goal != originalGoal
            || howToPlay != originalHowToPlay
            || materials != originalMaterials
            || (idealParticipants ?? originalParticipants) != originalParticipants
            || selectedCategories != originalCategories
            || composedDuration() != originalDuration
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleSection
                    participantSection
                    durationSection
                    categorySection
                    goalSection
                    materialSection
                    instructionsSection
                    Color.clear.frame(height: 72)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            Button(action: save) {
                Text("Save")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .disabled(title.isEmpty || goal.isEmpty || howToPlay.isEmpty)
        }
        .navigationTitle("Edit Icebreakers")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBackTapped()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Keep Editing") { }
            Button("Discard Changes", role: .destructive) { dismiss() }
        } message: {
            Text("Your changes to this activity will be lost.")
        }
    }

    // MARK: - Helpers

    private func handleBackTapped() {
        if isDirty {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }

    private func save() {
        activity.name = title
        activity.participants = idealParticipants ?? originalParticipants
        activity.duration = composedDuration()
        activity.categories = Array(selectedCategories)
        activity.goal = goal
        activity.howToPlay = howToPlay
        activity.possibleProperties = materials
        dismiss()
    }

    private func composedDuration() -> String {
        durationMin == durationMax ? "\(durationMin) minutes" : "\(durationMin)-\(durationMax) minutes"
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

    // MARK: - Subviews

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Categories")
                .font(.subheadline)
                .fontWeight(.bold)

            CategoryChipEditor(selectedCategories: $selectedCategories)
        }
    }

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
                                .foregroundColor(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : accent)
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
}

#Preview {
    NavigationStack {
        EditIcebreakerView(activity: Activity.mockActivities[0])
    }
}
