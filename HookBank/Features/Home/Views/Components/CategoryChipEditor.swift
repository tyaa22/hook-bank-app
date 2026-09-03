import SwiftUI
import Core

/// Inline editor for the 7 fixed activity categories: already-picked ones render as removable
/// chips, and typing into the field surfaces the remaining categories as tappable suggestions
/// (all of them when the field is empty, so focusing it alone shows everything there is to pick
/// from) so a category can be added either by tapping a suggestion or by typing its full name and
/// submitting. Shared by the Add and Edit Icebreaker forms so both behave identically.
struct CategoryChipEditor: View {
    @Binding var selectedCategories: Set<String>

    @State private var categoryInput: String = ""
    @FocusState private var isFieldFocused: Bool

    private let accent = Color("PrimaryAccentColor")
    private let grayBackground = Color("CardBackgroundColor")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedCategories.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedCategories.sorted(), id: \.self) { category in
                        HStack(spacing: 6) {
                            Text(category)
                            Button {
                                selectedCategories.remove(category)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accent.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }

            TextField("Add a category", text: $categoryInput)
                .focused($isFieldFocused)
                .submitLabel(.done)
                .onSubmit { commitInput() }
                .padding()
                .background(grayBackground)
                .cornerRadius(20)

            if isFieldFocused && !suggestions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            selectedCategories.insert(suggestion)
                            categoryInput = ""
                        } label: {
                            Text(suggestion)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().stroke(Color.secondary.opacity(0.4))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var suggestions: [String] {
        let remaining = ActivityCategory.allCases.map(\.rawValue).filter { !selectedCategories.contains($0) }
        let trimmed = categoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return remaining }
        return remaining.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Adds the typed text as a category when it matches one of the 7 fixed values by name
    /// (case-insensitive) — lets someone type the full word out instead of tapping a suggestion.
    private func commitInput() {
        let trimmed = categoryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let match = ActivityCategory.allCases.first(where: { $0.rawValue.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            selectedCategories.insert(match.rawValue)
        }
        categoryInput = ""
    }
}
