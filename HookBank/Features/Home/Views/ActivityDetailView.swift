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
    @State private var showEditPage = false

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

                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 13))
                                Text("\(activity.participants) person")
                            }

                            if activity.duration != "-" {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 13))
                                    Text(activity.duration)
                                }
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.gray)

                        if !activity.categories.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(activity.categories, id: \.self) { category in
                                    Text(category)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(orange)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(orange.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, 4)
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
                    showEditPage = true
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
        .navigationDestination(isPresented: $showEditPage) {
            EditIcebreakerView(activity: activity)
        }
        .confirmationDialog(
            "Delete Icebreaker",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep") {
                showDeleteConfirm.toggle()
            }
            Button("Delete", role: .destructive) {
                context.delete(activity)
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this icebreaker? \nThis action cannot be undone.")
        }
    }
}

// MARK: - Reusable sub-views

/// White card with a header row (icon badge + title) and arbitrary content below.
private struct SectionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .semibold))
                }
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

/// Wraps its children onto multiple rows instead of forcing them into one `HStack`, so a variable
/// number of category chips fills the available width and overflows onto a new line rather than
/// clipping or squeezing.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActivityDetailView(activity: Activity.mockActivities[0], viewModel: HomeViewModel())
    }
}
