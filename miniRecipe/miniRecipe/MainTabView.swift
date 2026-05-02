//
//  MainTabView.swift
//  miniRecipe
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var selectedTab: Tab = .recipes

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tag(Tab.recipes)
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }

            NotificationsListView()
                .tag(Tab.activity)
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .optionalTabBadge(supabase.unreadNotificationCount)

            CurrentUserProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .task {
            await supabase.refreshUnreadNotificationCount()
        }
        .sheet(isPresented: $supabase.globalAuthSheetPresented) {
            AuthView(showsDismissButton: true) { success in
                supabase.globalAuthSheetPresented = false
                if success {
                    Task {
                        await supabase.refreshUnreadNotificationCount()
                        NotificationCenter.default.post(name: .miniRecipeLibraryDidChange, object: nil)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .miniRecipeOpenCurrentProfileTab)) { _ in
            selectedTab = .profile
        }
    }
}

private enum Tab {
    case recipes
    case activity
    case profile
}

private extension View {
    /// Only show a tab badge when there is something to read (avoids an empty badge).
    @ViewBuilder
    func optionalTabBadge(_ count: Int) -> some View {
        if count > 0 {
            self.badge(count)
        } else {
            self
        }
    }
}
