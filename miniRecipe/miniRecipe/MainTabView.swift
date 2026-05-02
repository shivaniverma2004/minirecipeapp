//
//  MainTabView.swift
//  miniRecipe
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var supabase: SupabaseManager

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }

            NotificationsListView()
                .tabItem {
                    Label("Activity", systemImage: "bell.fill")
                }
                .optionalTabBadge(supabase.unreadNotificationCount)

            CurrentUserProfileView()
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
    }
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
