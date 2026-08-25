import SwiftUI
import Core

public struct AddHookView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: HomeViewModel
    
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
    
    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(grayBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Add Hook")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: saveHook) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
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
                            Stepper(value: $minParticipants, in: 1...100) {
                                HStack {
                                    Text("Minimum")
                                        .foregroundColor(Color(white: 0.7))
                                    Spacer()
                                    Text("\(minParticipants)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            
                            Divider().padding(.horizontal)
                            
                            Stepper(value: $maxParticipants, in: minParticipants...100) {
                                HStack {
                                    Text("Maximum")
                                        .foregroundColor(Color(white: 0.7))
                                    Spacer()
                                    Text("\(maxParticipants)")
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                        }
                        .background(grayBackground)
                        .cornerRadius(20)
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
    }
    
    private func saveHook() {
        let newHook = Activity(
            name: title,
            participants: "\(minParticipants)-\(maxParticipants)",
            goal: goal,
            howToPlay: howToPlay,
            possibleProperties: materials
        )
        viewModel.addActivity(newHook)
        dismiss()
    }
}

#Preview {
    AddHookView(viewModel: HomeViewModel())
}
