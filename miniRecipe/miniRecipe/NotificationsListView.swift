//
//  NotificationsListView.swift
//  miniRecipe
//

import SwiftUI

struct NotificationsListView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var items: [AppNotification] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selectedRecipe: Recipe?
    @State private var selectedProfileRoute: ProfileRoute?

    var body: some View {
        NavigationStack {
            Group {
                if !supabase.isSignedIn {
                    ContentUnavailableView {
                        Label("Activity", systemImage: "bell")
                    } description: {
                        Text("Sign in to see likes and follows.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } actions: {
                        Button("Sign in") {
                            supabase.requestGlobalSignIn()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if loading && items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = error {
                    ContentUnavailableView {
                        Label("Couldn’t load activity", systemImage: "bell.slash")
                    } description: {
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } actions: {
                        Button("Try again") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else if items.isEmpty {
                    ContentUnavailableView {
                        Label("No notifications yet", systemImage: "bell")
                    } description: {
                        Text("When someone likes your recipe or follows you, it will show here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(items) { n in
                            Button {
                                Task { await openNotification(n) }
                            } label: {
                                NotificationRow(notification: n)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if items.contains(where: \.isUnread) {
                        Button("Mark all read") {
                            Task { await markAll() }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
                    .environmentObject(supabase)
            }
            .navigationDestination(item: $selectedProfileRoute) { route in
                ProfileView(userId: route.id, isSelf: false)
                    .environmentObject(supabase)
            }
        }
    }

    private func openNotification(_ n: AppNotification) async {
        await markRead(n)

        if n.type == "like", let recipeId = n.recipeId?.lowercased() {
            do {
                let recipe = try await supabase.fetchRecipe(id: recipeId)
                await MainActor.run { selectedRecipe = recipe }
            } catch {
                AppLog.notifications("open recipe from notification failed: \(error.localizedDescription)")
            }
            return
        }

        if n.type == "follow", let actor = n.actorId?.lowercased() {
            if actor == supabase.currentUserIdString {
                NotificationCenter.default.post(name: .miniRecipeOpenCurrentProfileTab, object: nil)
            } else {
                await MainActor.run {
                    selectedProfileRoute = ProfileRoute(id: actor)
                }
            }
        }
    }

    private func load() async {
        guard supabase.isSignedIn else {
            items = []
            loading = false
            return
        }
        loading = true
        error = nil
        defer { loading = false }
        do {
            items = try await supabase.fetchNotifications()
            await supabase.refreshUnreadNotificationCount()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func markRead(_ n: AppNotification) async {
        guard n.isUnread else { return }
        do {
            try await supabase.markNotificationRead(id: n.id)
            await load()
        } catch {
            AppLog.notifications("mark read failed: \(error.localizedDescription)")
        }
    }

    private func markAll() async {
        do {
            try await supabase.markAllNotificationsRead()
            await load()
        } catch {
            AppLog.notifications("mark all read failed: \(error.localizedDescription)")
        }
    }
}

private struct ProfileRoute: Identifiable, Hashable {
    let id: String
}

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundStyle(notification.isUnread ? .primary : .secondary)
                if let b = notification.body, !b.isEmpty {
                    Text(b)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let created = notification.createdAt, let date = ISO8601DateFormatter().date(from: created) {
                    Text(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
            if notification.isUnread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Unread")
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch notification.type {
        case "like": return "hand.thumbsup.fill"
        case "follow": return "person.badge.plus"
        default: return "bell.fill"
        }
    }
}
