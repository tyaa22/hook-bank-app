import SwiftUI
import SwiftData
import Core

public struct AddHookView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var viewModel: HomeViewModel
    var activityToEdit: Activity? = nil
    
    @State private var title: String = ""
    @State private var minParticipants: Int = 1
    @State private var maxParticipants: Int = 10
    @State private var goal: String = ""
    
    // Materials
    
    @State private var materials: [String] = []
    @State private var newMaterial: String = ""
    
    // Instructions
    @State private var howToPlay: String = ""
    
    let grayBackground = Color("CardBackgroundColor")
    
    private var isEditMode: Bool { activityToEdit != nil }
    private var headerTitle: String { isEditMode ? "Edit Hook" : "Add Hook" }
    
    public init(viewModel: HomeViewModel, activityToEdit: Activity? = nil) {
        self.viewModel = viewModel
        self.activityToEdit = activityToEdit
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(grayBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(headerTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: saveHook) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 23, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color("PrimaryAccentColor"))
                        .clipShape(Circle())
                }
                // Disable save if required fields are empty
                .opacity(title.isEmpty || goal.isEmpty || howToPlay.isEmpty ? 0.5 : 1.0)
                .disabled(title.isEmpty || goal.isEmpty || howToPlay.isEmpty)
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        TextField("Enter activity name here...", text: $title)
                            .padding()
                            .background(grayBackground)
                            .cornerRadius(20)
                    }
                    
                    // Participant
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participant")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 0) {
                            Stepper(
                                onIncrement: {
                                    if minParticipants < 100 { minParticipants += 1 }
                                },
                                onDecrement: {
                                    if minParticipants > 1 { minParticipants -= 1 }
                                }
                            ) {
                                HStack {
                                    Text("Minimum")
                                        .foregroundColor(Color(white: 0.7))
                                    Spacer()
                                    TextField("", value: $minParticipants, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .fontWeight(.semibold)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
                            }
                            .padding()
                            
                            Divider().padding(.horizontal)
                            
                            Stepper(
                                onIncrement: {
                                    if maxParticipants < 100 { maxParticipants += 1 }
                                },
                                onDecrement: {
                                    if maxParticipants > minParticipants { maxParticipants -= 1 }
                                }
                            ) {
                                HStack {
                                    Text("Maximum")
                                        .foregroundColor(Color(white: 0.7))
                                    Spacer()
                                    TextField("", value: $maxParticipants, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .fontWeight(.semibold)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
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
                    
                    // Goal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        TextField("Enter goal here...", text: $goal, axis: .vertical)
                            .lineLimit(4...8)
                            .padding()
                            .background(grayBackground)
                            .cornerRadius(20)
                    }
                    
                    // Material
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
                                TextField("Add a material", text: $newMaterial)
                                
                                Button(action: {
                                    let trimmed = newMaterial.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty && !materials.contains(trimmed) {
                                        materials.append(trimmed)
                                        newMaterial = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor( Color("PrimaryAccentColor"))
                                        .opacity(newMaterial.isEmpty ? 0.5 : 1)
                                }
                                .disabled(newMaterial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding()
                        .background(grayBackground)
                        .cornerRadius(20)
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Play")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        
                        TextField("Enter instructions here...", text: $howToPlay, axis: .vertical)
                            .lineLimit(6...12)
                            .padding()
                            .background(grayBackground)
                            .cornerRadius(20)
                    }
                    
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .onAppear { prefillIfEditing() }
    }
    
    // MARK: - Helpers
    
    private func prefillIfEditing() {
        guard let activity = activityToEdit else { return }
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
        }
        dismiss()
    }
}

#Preview("Add Mode") {
    AddHookView(viewModel: HomeViewModel())
}

#Preview("Edit Mode") {
    AddHookView(viewModel: HomeViewModel(), activityToEdit: Activity.mockActivities[0])
}
