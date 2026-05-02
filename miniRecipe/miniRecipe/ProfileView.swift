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
    var isSelf: Bool

    init(userId: String, isSelf: Bool) {
        self.userId = userId.lowercased()
        self.isSelf = isSelf
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

    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    if loading && profile == nil {
                        ProgressView()
                            .padding(.vertical, 24)
                    } else {
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
                            statBlock(count: followers, title: "Followers")
                            statBlock(count: following, title: "Following")
                        }
                        .padding(.vertical, 4)

                        if !isSelf {
                            if supabase.isSignedIn {
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
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
        .toolbar {
            if isSelf {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AccountSettingsView()
                            .environmentObject(supabase)
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Account settings")
                }
            }
        }
        .task(id: userId) { await load() }
        .refreshable { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .miniRecipeProfileUpdated)) { _ in
            avatarImageVersion += 1
            Task { await load() }
        }
    }

    private func statBlock(count: Int, title: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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
