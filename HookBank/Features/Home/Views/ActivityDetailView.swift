import SwiftUI
import SwiftData
import Core

struct ActivityDetailView: View {
    @Environment(\.modelContext) private var context
    let activity: Activity
    var viewModel: HomeViewModel = HomeViewModel()
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private let orange = Color("PrimaryAccentColor")
    private let bg = Color("CardBackgroundColor")
    private let cardBG = Color.white

    var body: some View {
        ZStack(alignment: .top) {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // ── Title + Participants ──────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Text(activity.name)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.black)

                        if activity.participants != "-" {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 13))
                                Text(activity.participants)
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // ── Goal Card ─────────────────────────────────────────────
                    SectionCard(
                        icon: "flag.fill",
                        iconColor: orange,
                        title: "Goal"
                    ) {
                        Text(activity.goal)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // ── Materials Card ────────────────────────────────────────
                    if !activity.possibleProperties.isEmpty &&
                       !(activity.possibleProperties.count == 1 && activity.possibleProperties[0] == "-") {
                        SectionCard(
                            icon: "backpack.fill",
                            iconColor: orange,
                            title: "Materials"
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(activity.possibleProperties, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("·")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text(item)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }

                    // ── Instruction Card ──────────────────────────────────────
                    SectionCard(
                        icon: "list.number",
                        iconColor: orange,
                        title: "Instruction"
                    ) {
                        Text(activity.howToPlay)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddHookView(viewModel: viewModel, activityToEdit: activity)
        }
        .confirmationDialog(
            "Delete Hook",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep Hook") {
                showDeleteConfirm.toggle()
            }
            Button("Delete Hook", role: .destructive) {
                context.delete(activity)
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this hook? \nThis action cannot be undone.")
        }
    }
}

// MARK: - Reusable sub-views

/// White card with a header row (icon + title) and arbitrary content below.
private struct SectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityDetailView(activity: Activity.mockActivities[0], viewModel: HomeViewModel())
    }
}
