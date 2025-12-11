//
//  RecipeDetailView.swift
//  miniRecipe
//
//  Created by Shivani Verma on 11/12/25.

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    // Local optimistic state for likes (not persisted unless you implement an API)
    @State private var localLikes: Int
    @State private var liked: Bool = false
    @State private var showingShare = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _localLikes = State(initialValue: recipe.likes ?? 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                if let urlString = recipe.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                Color(white: 0.95)
                                ProgressView()
                            }
                            .frame(height: 240)
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFill()
                                .frame(height: 240)
                                .clipped()
                        case .failure:
                            ZStack {
                                Color(white: 0.95)
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 240)
                        @unknown default:
                            EmptyView()
                                .frame(height: 240)
                        }
                    }
                    .cornerRadius(8)
                } else {
                    ZStack {
                        Color(white: 0.95)
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 240)
                    .cornerRadius(8)
                }

                // Title + meta
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.title)
                        .bold()
                        .lineLimit(3)

                    HStack(alignment: .center, spacing: 12) {
                        authorBadge
                        VStack(alignment: .leading, spacing: 2) {
                            if let created = formattedDate {
                                Text(created)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let relative = relativeDate {
                                Text(relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Like + Share buttons
                        HStack(spacing: 12) {
                            Button(action: toggleLike) {
                                HStack(spacing: 6) {
                                    Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    Text("\(localLikes)")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(liked ? .accentColor : .gray)

                            Button(action: { showingShare = true }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // Description
                if let desc = recipe.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(desc)
                        .font(.body)
                        .padding(.top, 6)
                } else {
                    Text("No description provided.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare) {
            // simple share sheet
            let items: [Any] = [recipe.title, recipe.imageURL].compactMap { $0 }
            ActivityView(activityItems: items)
        }
    }

    // MARK: - Subviews

    private var authorBadge: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 40, height: 40)
                Text(authorInitials)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(authorDisplay)
                    .font(.subheadline)
                    .bold()
                Text(authorSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func toggleLike() {
        // Optimistic UI update. To persist likes, call your SupabaseManager update method here.
        liked.toggle()
        localLikes += liked ? 1 : -1
        // TODO: call SupabaseManager.shared.updateRecipeLikes(id: recipe.id, likes: localLikes)
    }

    // MARK: - Helpers

    private var authorInitials: String {
        if let id = recipe.authorID, !id.isEmpty {
            // show first 2 chars of author id as fallback
            return String(id.prefix(2)).uppercased()
        }
        return "U"
    }

    private var authorDisplay: String {
        if let id = recipe.authorID, !id.isEmpty {
            return "User \(String(id.prefix(8)))"
        }
        return "Unknown"
    }

    private var authorSubtitle: String {
        if recipe.authorID != nil { "Author" } else { "" }
    }

    private var formattedDate: String? {
        guard let iso = recipe.createdAt else { return nil }
        if let date = ISO8601DateFormatter().date(from: iso) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
        return nil
    }

    private var relativeDate: String? {
        guard let iso = recipe.createdAt,
              let date = ISO8601DateFormatter().date(from: iso)
        else { return nil }
        let rf = RelativeDateTimeFormatter()
        rf.unitsStyle = .short
        return rf.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - ActivityView wrapper for share sheet
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#if DEBUG
struct RecipeDetailView_Previews: PreviewProvider {
    static var sample = Recipe(
        id: UUID().uuidString,
        title: "Spicy Masala Pasta",
        description: "A delicious pasta tossed in Indian masala and fresh veggies.",
        imageURL: nil,
        authorID: "12345678-90ab",
        likes: 8,
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600 * 24 * 2))
    )

    static var previews: some View {
        NavigationView {
            RecipeDetailView(recipe: sample)
        }
    }
}
#endif
