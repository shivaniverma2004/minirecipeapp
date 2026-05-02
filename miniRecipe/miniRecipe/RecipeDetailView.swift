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
    @State private var showLikers = false
    @State private var selectedAuthorProfileRoute: AuthorProfileRoute?

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
                await syncLikedState()
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
            .sheet(isPresented: $showLikers) {
                NavigationStack {
                    LikersListView(recipeId: recipe.id)
                        .environmentObject(supabase)
                }
            }
            .navigationDestination(item: $selectedAuthorProfileRoute) { route in
                ProfileView(userId: route.id, isSelf: false)
                    .environmentObject(supabase)
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
            Button {
                openAuthorProfile(aid)
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
            likeToggleButton
            likesCountButton
            shareTriggerButton
            Spacer(minLength: 0)
        }
    }

    private var likeToggleButton: some View {
        Button(action: {
            if supabase.isSignedIn {
                toggleLike()
            } else {
                supabase.requestGlobalSignIn()
            }
        }) {
            Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
        .buttonStyle(.borderedProminent)
        .tint(liked ? Color.accentColor : Color.gray)
        .controlSize(.large)
        .disabled(likeBusy)
        .accessibilityLabel(liked ? "Unlike recipe" : "Like recipe")
    }

    private var likesCountButton: some View {
        Button {
            showLikers = true
        } label: {
            Label("\(localLikes)", systemImage: "person.2.fill")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel("View likes")
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
        guard !likeBusy else { return }
        let previousLiked = liked
        let previousCount = localLikes
        likeBusy = true
        likeSyncError = nil
        Task {
            do {
                let result = try await supabase.toggleRecipeLike(recipeId: recipe.id)
                await MainActor.run {
                    liked = result.liked
                    localLikes = result.count
                    likeSyncError = nil
                }
                if !previousLiked, result.liked, let author = recipe.authorID, let me = supabase.currentUserIdString,
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

    private func syncLikedState() async {
        guard supabase.isSignedIn else {
            await MainActor.run { liked = false }
            return
        }
        do {
            let mine = try await supabase.isRecipeLikedByMe(recipeId: recipe.id)
            await MainActor.run { liked = mine }
        } catch {
            AppLog.recipe("sync liked state failed: \(error.localizedDescription)")
        }
    }

    private func openAuthorProfile(_ authorId: String) {
        let id = authorId.lowercased()
        if id == supabase.currentUserIdString {
            NotificationCenter.default.post(name: .miniRecipeOpenCurrentProfileTab, object: nil)
        } else {
            selectedAuthorProfileRoute = AuthorProfileRoute(id: id)
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

private struct LikersListView: View {
    let recipeId: String

    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var error: String?
    @State private var likers: [Profile] = []
    @State private var selectedProfileRoute: LikerProfileRoute?

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Couldn’t load likes", systemImage: "hand.thumbsup.slash", description: Text(error))
            } else if likers.isEmpty {
                ContentUnavailableView("No likes yet", systemImage: "hand.thumbsup")
            } else {
                List(likers, id: \.id) { profile in
                    if let profileId = profile.id {
                        Button {
                            openProfile(profileId)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(urlString: profile.avatarURL, initials: profile.initials, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(for: profile))
                                        .font(.headline)
                                        .lineLimit(1)
                                    if let email = profile.email, !email.isEmpty {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Likes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .navigationDestination(item: $selectedProfileRoute) { route in
            ProfileView(userId: route.id, isSelf: false)
                .environmentObject(supabase)
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            likers = try await supabase.fetchRecipeLikers(recipeId: recipeId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func displayName(for profile: Profile) -> String {
        let trimmedName = profile.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty { return trimmedName }
        if let email = profile.email, !email.isEmpty { return email }
        return "Cook"
    }

    private func openProfile(_ profileId: String) {
        let id = profileId.lowercased()
        if id == supabase.currentUserIdString {
            dismiss()
            NotificationCenter.default.post(name: .miniRecipeOpenCurrentProfileTab, object: nil)
        } else {
            selectedProfileRoute = LikerProfileRoute(id: id)
        }
    }
}

private struct LikerProfileRoute: Identifiable, Hashable {
    let id: String
}

private struct AuthorProfileRoute: Identifiable, Hashable {
    let id: String
}
