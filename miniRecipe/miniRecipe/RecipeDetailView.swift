//
//  RecipeDetailView.swift
//  miniRecipe
//

import SwiftUI

struct RecipeDetailView: View {
    @State private var recipe: Recipe

    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var localLikes: Int
    @State private var liked: Bool = false
    @State private var showingShare = false
    @State private var authorProfile: Profile?
    @State private var likeBusy = false
    @State private var likeSyncError: String?
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var deleteBusy = false

    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 280

    init(recipe: Recipe) {
        _recipe = State(initialValue: recipe)
        _localLikes = State(initialValue: recipe.likes ?? 0)
    }

    private var isOwner: Bool {
        guard let me = supabase.currentUserIdString, let aid = recipe.authorID else { return false }
        return me == aid
    }

    var body: some View {
        scrollColumn
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isOwner {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Edit recipe", systemImage: "pencil") { showEdit = true }
                            Button("Delete recipe", systemImage: "trash", role: .destructive) {
                                confirmDelete = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Recipe actions")
                    }
                }
            }
            .task(id: recipe.id) {
                await refreshFromServer()
                await loadAuthor()
            }
            .sheet(isPresented: $showingShare) {
                ActivityView(activityItems: shareActivityItems)
            }
            .sheet(isPresented: $showEdit) {
                EditRecipeView(recipe: recipe) {
                    Task {
                        await refreshFromServer()
                        await loadAuthor()
                    }
                }
                .environmentObject(supabase)
            }
            .confirmationDialog(
                "Delete this recipe? This can’t be undone.",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await deleteRecipe() } }
                Button("Cancel", role: .cancel) {}
            }
    }

    private var shareActivityItems: [Any] {
        var items: [Any] = [recipe.title]
        if let u = recipe.imageURL { items.append(u) }
        return items
    }

    private var scrollColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                titleAuthorAndActions

                Divider()
                    .padding(.vertical, 4)

                descriptionBlock

                if let created = formattedDate {
                    Text(created)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var titleAuthorAndActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            authorLinkOrRow

            likeAndShareRow

            if !supabase.isSignedIn {
                Text("Sign in to like recipes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let err = likeSyncError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var authorLinkOrRow: some View {
        if let aid = recipe.authorID, !aid.isEmpty {
            NavigationLink {
                ProfileView(userId: aid, isSelf: isOwner)
            } label: {
                authorRow
            }
            .buttonStyle(.plain)
        } else {
            authorRow
        }
    }

    private var likeAndShareRow: some View {
        HStack(spacing: 12) {
            likeButton
            shareTriggerButton
            Spacer(minLength: 0)
        }
    }

    private var likeButton: some View {
        Button(action: toggleLike) {
            Label(
                "\(localLikes)",
                systemImage: liked ? "hand.thumbsup.fill" : "hand.thumbsup"
            )
            .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .tint(liked ? Color.accentColor : Color.gray)
        .controlSize(.large)
        .disabled(likeBusy || !supabase.isSignedIn)
    }

    private var shareTriggerButton: some View {
        Button {
            showingShare = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private var descriptionBlock: some View {
        if let desc = recipe.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(desc)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No description.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshFromServer() async {
        do {
            let latest = try await supabase.fetchRecipe(id: recipe.id)
            await MainActor.run {
                recipe = latest
                localLikes = latest.likes ?? localLikes
            }
        } catch {
            AppLog.recipe("refresh failed: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let s = recipe.imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            RemoteImage(urlString: recipe.imageURL, version: 0, contentMode: .fill)
        } else {
            placeholderHero
        }
    }

    private var placeholderHero: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(.secondary)
        }
    }

    private var authorRow: some View {
        HStack(spacing: 14) {
            AvatarView(
                urlString: authorProfile?.avatarURL,
                initials: authorInitials,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(authorDisplay)
                    .font(.headline)
                Text("View profile")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens author profile")
    }

    private func loadAuthor() async {
        guard let aid = recipe.authorID, !aid.isEmpty else { return }
        do {
            let p = try await supabase.fetchProfile(by: aid)
            await MainActor.run { authorProfile = p }
        } catch {
            AppLog.recipe("author profile load failed: \(error.localizedDescription)")
        }
    }

    private func toggleLike() {
        guard supabase.isSignedIn, !likeBusy else { return }
        let previousLiked = liked
        let previousCount = localLikes
        if liked {
            liked = false
            localLikes = max(0, localLikes - 1)
        } else {
            liked = true
            localLikes += 1
        }
        likeBusy = true
        likeSyncError = nil
        let id = recipe.id.lowercased()
        let count = localLikes
        Task {
            do {
                try await supabase.setRecipeLikes(recipeId: id, likes: count)
                await MainActor.run { likeSyncError = nil }
                if !previousLiked, liked, let author = recipe.authorID, let me = supabase.currentUserIdString,
                   author != me {
                    await sendLikeNotification()
                }
            } catch {
                await MainActor.run {
                    liked = previousLiked
                    localLikes = previousCount
                    likeSyncError = UserFacingAPIError.message(for: error)
                }
            }
            await MainActor.run { likeBusy = false }
        }
    }

    private func sendLikeNotification() async {
        guard let me = supabase.currentUserIdString,
              let author = recipe.authorID,
              author != me else { return }
        do {
            let p = try await supabase.fetchProfile(by: me)
            let trimmed = p?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = !trimmed.isEmpty ? trimmed : (p?.email ?? "Someone")
            try await supabase.insertNotification(
                SupabaseManager.NotificationInsert(
                    user_id: author,
                    actor_id: me,
                    type: "like",
                    title: "\(name) liked your recipe",
                    body: recipe.title,
                    recipe_id: recipe.id
                )
            )
            await supabase.refreshUnreadNotificationCount()
        } catch {
            AppLog.recipe("like notification insert failed: \(error.localizedDescription)")
        }
    }

    private func deleteRecipe() async {
        deleteBusy = true
        defer { deleteBusy = false }
        do {
            try await supabase.deleteRecipe(id: recipe.id)
            NotificationCenter.default.post(name: .miniRecipeLibraryDidChange, object: nil)
            await MainActor.run { dismiss() }
        } catch {
            await MainActor.run {
                likeSyncError = error.localizedDescription
            }
        }
    }

    private var authorInitials: String {
        if let p = authorProfile {
            let i = p.initials
            if !i.isEmpty, i != "??" { return i }
        }
        if let id = recipe.authorID, !id.isEmpty {
            return String(id.prefix(2)).uppercased()
        }
        return "?"
    }

    private var authorDisplay: String {
        if let name = authorProfile?.displayName, !name.isEmpty { return name }
        if let email = authorProfile?.email, !email.isEmpty { return email }
        if let id = recipe.authorID, !id.isEmpty {
            return "Cook · \(String(id.prefix(8)))"
        }
        return "Unknown author"
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
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
