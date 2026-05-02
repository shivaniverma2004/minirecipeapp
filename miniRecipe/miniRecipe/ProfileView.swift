//
//  ProfileView.swift
//  miniRecipe
//

import SwiftUI

struct CurrentUserProfileView: View {
    @EnvironmentObject private var supabase: SupabaseManager

    var body: some View {
        NavigationStack {
            if let id = supabase.currentUserIdString {
                ProfileView(userId: id, isSelf: true)
            } else {
                ContentUnavailableView {
                    Label("Sign in", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("Create an account to save recipes, follow cooks, and customize your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } actions: {
                    Button("Sign in") {
                        supabase.requestGlobalSignIn()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Profile")
            }
        }
    }
}

struct ProfileView: View {
    let userId: String
    private let isSelfHint: Bool

    init(userId: String, isSelf: Bool) {
        self.userId = userId.lowercased()
        self.isSelfHint = isSelf
    }

    @EnvironmentObject private var supabase: SupabaseManager
    @State private var profile: Profile?
    @State private var avatarImageVersion = 0
    @State private var recipes: [Recipe] = []
    @State private var followers = 0
    @State private var following = 0
    @State private var isFollowing = false
    @State private var followBusy = false
    @State private var loading = true
    @State private var followersListPresented = false
    @State private var followingListPresented = false
    @State private var showSignOutConfirm = false

    private var isSelf: Bool {
        guard let me = supabase.currentUserIdString else { return isSelfHint }
        return me == userId || isSelfHint
    }

    var body: some View {
        List {
            Section {
                profileHeaderCard
                    .padding(.vertical, 6)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                if recipes.isEmpty && !loading {
                    ContentUnavailableView(
                        "No recipes yet",
                        systemImage: "fork.knife",
                        description: Text(isSelf ? "Your recipes will show up here." : "This cook hasn’t posted yet.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                } else {
                    ForEach(recipes) { recipe in
                        NavigationLink(value: recipe) {
                            RecipeRow(recipe: recipe)
                        }
                    }
                }
            } header: {
                Text("Recipes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(isSelf ? "Profile" : displayName)
        .navigationBarTitleDisplayMode(isSelf ? .large : .inline)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
                .environmentObject(supabase)
        }
        .task(id: userId) { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .miniRecipeProfileUpdated)) { _ in
            avatarImageVersion += 1
            Task { await load() }
        }
        .sheet(isPresented: $followersListPresented) {
            NavigationStack {
                FollowListView(userId: userId, mode: .followers)
                    .environmentObject(supabase)
            }
        }
        .sheet(isPresented: $followingListPresented) {
            NavigationStack {
                FollowListView(userId: userId, mode: .following)
                    .environmentObject(supabase)
            }
        }
        .confirmationDialog("Sign out of miniRecipe?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    try? await supabase.signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var profileHeaderCard: some View {
        if loading && profile == nil {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 18) {
                AvatarView(
                    urlString: profile?.avatarURL,
                    initials: profile?.initials ?? "??",
                    size: 96,
                    imageVersion: avatarImageVersion
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Profile photo for \(displayName)")

                VStack(spacing: 6) {
                    Text(displayName)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    if let email = profile?.email, isSelf {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 0) {
                    statButton(count: followers, title: "Followers") {
                        followersListPresented = true
                    }
                    statButton(count: following, title: "Following") {
                        followingListPresented = true
                    }
                }
                .padding(.vertical, 2)

                if isSelf {
                    NavigationLink {
                        AccountSettingsView()
                            .environmentObject(supabase)
                    } label: {
                        Label("Edit profile", systemImage: "slider.horizontal.3")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Sign out", role: .destructive) {
                        showSignOutConfirm = true
                    }
                    .font(.subheadline.weight(.semibold))
                } else if supabase.isSignedIn {
                    followControl
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sign in to follow \(displayName) and see more activity.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Sign in") {
                            supabase.requestGlobalSignIn()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
        }
    }

    private func statButton(count: Int, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        if let n = profile?.displayName, !n.isEmpty { return n }
        if let e = profile?.email { return e }
        return "Cook"
    }

    @ViewBuilder
    private var followControl: some View {
        if isFollowing {
            Button {
                Task { await toggleFollow() }
            } label: {
                if followBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Following")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(followBusy)
        } else {
            Button {
                Task { await toggleFollow() }
            } label: {
                if followBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Follow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(followBusy)
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            profile = try await supabase.fetchProfile(by: userId)
            recipes = try await supabase.fetchRecipes(byAuthorId: userId)
            followers = try await supabase.followerCount(userId: userId)
            following = try await supabase.followingCount(userId: userId)
            if !isSelf, supabase.isSignedIn {
                isFollowing = try await supabase.isFollowing(userId: userId)
            } else {
                isFollowing = false
            }
        } catch {
            AppLog.profile("load failed: \(error.localizedDescription)")
        }
    }

    private func toggleFollow() async {
        followBusy = true
        defer { followBusy = false }
        do {
            if isFollowing {
                try await supabase.unfollow(userId: userId)
                isFollowing = false
                followers = max(0, followers - 1)
            } else {
                try await supabase.follow(userId: userId)
                isFollowing = true
                followers += 1
                await sendFollowNotification()
            }
        } catch {
            AppLog.profile("follow toggle failed: \(error.localizedDescription)")
        }
    }

    private func sendFollowNotification() async {
        guard let me = supabase.currentUserIdString else { return }
        do {
            let p = try await supabase.fetchProfile(by: me)
            let trimmed = p?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name = !trimmed.isEmpty ? trimmed : (p?.email ?? "Someone")
            try await supabase.insertNotification(
                SupabaseManager.NotificationInsert(
                    user_id: userId,
                    actor_id: me,
                    type: "follow",
                    title: "\(name) started following you",
                    body: nil,
                    recipe_id: nil
                )
            )
            await supabase.refreshUnreadNotificationCount()
        } catch {
            AppLog.profile("follow notification insert failed: \(error.localizedDescription)")
        }
    }
}

private enum FollowListMode: String {
    case followers
    case following

    var title: String {
        switch self {
        case .followers: return "Followers"
        case .following: return "Following"
        }
    }
}

private struct FollowListView: View {
    let userId: String
    let mode: FollowListMode

    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var error: String?
    @State private var people: [Profile] = []
    @State private var selectedProfileRoute: FollowProfileRoute?

    var body: some View {
        Group {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Couldn’t load \(mode.title.lowercased())", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if people.isEmpty {
                ContentUnavailableView("No \(mode.title.lowercased()) yet", systemImage: "person.2")
            } else {
                List(people, id: \.id) { person in
                    if let pid = person.id {
                        Button {
                            openProfile(pid)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(urlString: person.avatarURL, initials: person.initials, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(for: person))
                                        .font(.headline)
                                        .lineLimit(1)
                                    if let email = person.email, !email.isEmpty {
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
        .navigationTitle(mode.title)
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
            if mode == .followers {
                people = try await supabase.fetchFollowers(userId: userId)
            } else {
                people = try await supabase.fetchFollowing(userId: userId)
            }
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
            selectedProfileRoute = FollowProfileRoute(id: id)
        }
    }
}

private struct FollowProfileRoute: Identifiable, Hashable {
    let id: String
}
